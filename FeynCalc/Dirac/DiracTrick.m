(* ::Package:: *)



(* :Title: DiracTrick                                                       *)

(*
	This software is covered by the GNU General Public License 3.
	Copyright (C) 1990-2016 Rolf Mertig
	Copyright (C) 1997-2016 Frederik Orellana
	Copyright (C) 2014-2016 Vladyslav Shtabovenko
*)

(* :Summary:  Contraction and simplification rules for Dirac matrices                                        *)

(* ------------------------------------------------------------------------ *)

DiracTrick::usage =
"DiracTrick[exp] contracts gamma matrices with each other and \
performs several simplifications (no expansion, use DiracSimplify for this).";

DiracTrick::failmsg =
"Error! DiracTrick has encountered a fatal problem and must abort the computation. \
The problem reads: `1`"


(* ------------------------------------------------------------------------ *)

Begin["`Package`"]
End[]

Begin["`DiracTrick`Private`"]

diTrVerbose::usage="";
diracTraceSimplify::usage="";
insideDiracTrace::usage="";
diga::usage="";

Options[DiracTrick] = {
	DiracGammaCombine -> False,
	Expanding -> False,
	FCI -> False,
	FCVerbose -> False,
	InsideDiracTrace -> False
};

scev[a_, b_] :=
	MemSet[scev[a, b],ExpandScalarProduct[Pair[a,b]]];
coneins[x_] :=
	MemSet[coneins[x],x /. Pair -> PairContract /. PairContract -> Pair];

(* TODO: Bad syntax that one should get rid off*)
DiracTrick[] = 1;

DiracTrick[y__ /; FreeQ[{y}, Rule, 1],z_/;Head[z]=!=Rule] :=
	DiracTrick[DOT[y,z],FCI->True];

DiracTrick[expr_,OptionsPattern[]] :=
	Block[{	res,tmp,ex,null1,null2,holdDOT,freePart,dsPart,diracObjects,
			diracObjectsEval, repRule},
		(*
			Main algorithm:
				1) Simplify expressions involving projectors and slashes (DOT ->  drS)
				2) Check the scheme and then simplify the expressions involving g^5 (drS /. drS ->  ds)
				3) Simplify expressions involving contractions of gamma matrices with momenta or other gammas (ds //. dr -> drCOs)
				4) Again check the sceme and simplify the expressions involving g^5 (twice) (drCO -> ds /.  dr -> ds /.  dr -> DOT)
		*)

		(*	Algorithm of DiracTrick:

			x)	Isolate all Dirac objects and handle them separately. Of course there is an extra option
				to skip this if the input is already a single object (e.g. when DiracTrick is called by
				DiracTrace or DiracSimplify) Then apply the evaluating function to each of the objects,
				create replacement rules (standard)	and substitute the results back.

			x) The inner working of the evaluating function:
				xx)		Check the dimension of the chain, could be purely 4-dim, purely D-dim or mixed (BMHV).
						Also check that BMHV was indeed activated if mixed dimensions appear

				xx)		Then we
							1) 	Handle g^5 if it is present
							2) 	Ensure that the expression is of the form .... g^5 or contains no g^5 at all,
								unless there are unknown non-commutative objects inside the chain or we use BMHV
							3)	Handle everything apart from g^5.
							4)	If we use BMHV, handle g^5 again, this time using anticommuting rules.
							5)	Notice that we use different functions for 4-dim, D-dim and mixed expressions
								to save time and ensure that e.g. no rules for mixed expressions are unsuccesfully
								applied to a purely 4-dim chain

				xx)		The handling of g^5 of course depends a lot on dimensions, the scheme and whether we are
						inside a trace or not.

						xxx) If we are purely 4-dim, then we do all the g^5 related simplifications in this step.
						xxx) If we are purely D-dim, not inside trace, and use NDR, then g^5 is anticommuted
						xxx) If we are purely D-dim, not inside trace, and use Larin or BMHV, then g^5 is left alone
						xxx) If we are purely D-dim, inside trace and use Larin, then g^5 is anticommuted and cyclicity is used
						xxx) If we are purely D-dim, inside trace and use BMHV, then only cyclicity is used

						xxx) If we are mixed (always BMHV), not inside trace, then g^5 is left alone
						xxx) If we are mixed (always BMHV), inside trace, then only cyclicity is used
						xxx) Notice that in all cases we use some generic properties of g^5, namely that
						(g^5)^2 = 1, g^6 g^7 = 0 etc.


		*)

		If [OptionValue[FCVerbose]===False,
			diTrVerbose=$VeryVerbose,
			If[MatchQ[OptionValue[FCVerbose], _Integer?Positive | 0],
				diTrVerbose=OptionValue[FCVerbose]
			];
		];

		FCPrint[1, "DiracTrick. Entering.", FCDoControl->diTrVerbose];
		FCPrint[3, "DiracTrick: Entering with ", expr, FCDoControl->diTrVerbose];

		If[ OptionValue[FCI],
			ex = expr,
			ex = FCI[expr]
		];

		If[	OptionValue[InsideDiracTrace],
			insideDiracTrace = True,
			insideDiracTrace = False
		];

		(* 	First of all we need to extract all the Dirac structures in the input. *)
		ex = FCDiracIsolate[ex,FCI->True,Head->dsHead, DotSimplify->True, DiracGammaCombine->OptionValue[DiracGammaCombine],Lorentz->True];

		{freePart,dsPart} = FCSplit[ex,{dsHead}];
		FCPrint[3,"DiracTrick: dsPart: ",dsPart , FCDoControl->diTrVerbose];
		FCPrint[3,"DiracTrick: freePart: ",freePart , FCDoControl->diTrVerbose];

		diracObjects = Cases[dsPart+null1+null2, dsHead[_], Infinity]//Union;
		diracObjectsEval = diracTrickEval/@(diracObjects/.dsHead->Identity);

		repRule = MapThread[Rule[#1,#2]&,{diracObjects,diracObjectsEval}];
		FCPrint[3,"DiracTrick: repRule: ",repRule , FCDoControl->diTrVerbose];

		res = freePart + ( dsPart/.repRule);

		If[	OptionValue[Expanding],
			res = Expand[res]
		];

		FCPrint[1, "DiracTrick. Leaving.", FCDoControl->diTrVerbose];
		FCPrint[3, "DiracTrick: Leaving with ", res, FCDoControl->diTrVerbose];

		res
	];


diracTrickEval[ex:DiracGamma[__]]:=
	ex/; !insideDiracTrace

diracTrickEval[DiracGamma[_[_,___],___]]:=
	0/; insideDiracTrace;

diracTrickEval[DiracGamma[5]]:=
	0/; insideDiracTrace;

diracTrickEval[DiracGamma[6|7]]:=
	1/2/; insideDiracTrace;

diracTrickEval[ex_/;Head[ex]=!=DiracGamma]:=
	Block[{res=ex, holdDOT, time, dim, gamma5Present,noncommPresent,null1,null2},

		FCPrint[1, "DiracTrick: diracTrickEval: Entering.", FCDoControl->diTrVerbose];
		FCPrint[3, "DiracTrick: diracTrickEval: Entering with", ex , FCDoControl->diTrVerbose];

		gamma5Present = !FreeQ2[ex,{DiracGamma[5],DiracGamma[6],DiracGamma[7]}];
		noncommPresent = !NonCommFreeQ[ex/.DiracGamma->diga];
		dim = FCGetDimensions[ex/.DiracGamma[5|6|7]:>diga];

		FCPrint[3, "DiracTrick: diracTrickEval: g^5 present:", gamma5Present, FCDoControl->diTrVerbose];
		FCPrint[3, "DiracTrick: diracTrickEval: unknown non-commutative objects present:", noncommPresent, FCDoControl->diTrVerbose];

		res = res/. DOT -> holdDOT;

		If[	gamma5Present,
			res = res /. holdDOT -> commonGamma5Properties /. commonGamma5Properties -> holdDOT;
			gamma5Present = !FreeQ2[res,{DiracGamma[5],DiracGamma[6],DiracGamma[7]}];
		];

		If[ res===0,
			Return[0]
		];

		If[	insideDiracTrace,
			time=AbsoluteTime[];
			FCPrint[1, "DiracTrick: diracTrickEval: Applying diracTraceSimplify ", FCDoControl->diTrVerbose];
			res = diracTraceSimplify[res] /. DOT -> holdDOT /. diracTraceSimplify[holdDOT[x__]] :> diracTraceSimplify[x]/.
			diracTraceSimplify -> commonGamma5Properties /. commonGamma5Properties -> holdDOT;
			FCPrint[1,"DiracTrace: diracTrickEval: diracTraceSimplify done, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose];
			FCPrint[3, "DiracTrick: diracTrickEval: After diracTraceSimplify ", res, FCDoControl->diTrVerbose],
			res = res /. DOT -> holdDOT;
		];

		If[	!FreeQ[res,Pair],
			res = Expand2[res,Pair]/. Pair->PairContract /. PairContract->Pair;
		];

		If[ res===0,
			Return[0]
		];

		(* TODO Checks here*)
		dim = FCGetDimensions[res/.DiracGamma[5|6|7]:>diga];
		noncommPresent = !NonCommFreeQ[res/.DiracGamma->diga];

		FCPrint[3, "DiracTrick: diracTrickEval: Dimensions:", dim, FCDoControl->diTrVerbose];

		If[	gamma5Present,

			time=AbsoluteTime[];
			FCPrint[1, "DiracTrick: diracTrickEval: Applying chiralTrick ", FCDoControl->diTrVerbose];
			Which[
					(* Purely 4-dimensional -> use anticommuting g^5 *)
					dim==={4},
						FCPrint[1, "DiracTrick: diracTrickEval: Purely 4-dim.", FCDoControl->diTrVerbose];
						res = res /. holdDOT -> chiralTrickAnticommutingSameDim /. chiralTrickAnticommutingSameDim -> holdDOT,
					(* Purely D-dimensional and NDR -> use anticommuting g^5 *)
					MatchQ[dim,{_Symbol}] && !$BreitMaison && !$Larin,
						FCPrint[1, "DiracTrick: diracTrickEval: Purely D-dim, NDR.", FCDoControl->diTrVerbose];
						res = res /. holdDOT -> chiralTrickAnticommutingSameDim /. chiralTrickAnticommutingSameDim -> holdDOT,
					(* Purely D-dimensional and Larin or BMHV -> don't move anything around *)
					MatchQ[dim,{_Symbol}] && (!$BreitMaison && $Larin) || ($BreitMaison && !$Larin),
						FCPrint[1, "DiracTrick: diracTrickEval: Purely D-dim and Larin or BMHV.", FCDoControl->diTrVerbose];
						Null,
					(* Mixed and BMHV -> don't move g^5 around, can apply drS *)
					MatchQ[dim, {4, _Symbol} || {4, _Symbol-4} || {_Symbol-4, _Symbol} || {4, _Symbol-4, _Symbol}] && $BreitMasion && !$Larin,
						FCPrint[1, "DiracTrick: diracTrickEval: Mixed and BMHV.", FCDoControl->diTrVerbose];
						res = res /.holdDOT -> drS /. drS -> holdDOT;
						FCPrint[3, "DiracTrick: diracTrickEval: After drS ", res, FCDoControl->diTrVerbose],
					(* Anything else is most likely an error *)
					True,
						Message[DiracTrick::failmsg,"Incorrect combination of dimensions and g^5 scheme!"];
						Abort[]
			];

			FCPrint[1,"DiracTrace: diracTrickEval: chiralTrick done, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose];
			FCPrint[3, "DiracTrick: diracTrickEval: After chiralTrick ", res, FCDoControl->diTrVerbose];
			gamma5Present = !FreeQ2[res,{DiracGamma[5],DiracGamma[6],DiracGamma[7]}];
		];

		res = res /.holdDOT -> ds;
		FCPrint[3, "DiracTrick: diracTrickEval: After ds ", res, FCDoControl->diTrVerbose];
		res = res  //. dr -> drCOs;
		FCPrint[3, "DiracTrick: diracTrickEval: After drCOs ", res, FCDoControl->diTrVerbose];
		res = res /.  drCO -> ds;
		FCPrint[3, "DiracTrick: diracTrickEval: After ds ", res, FCDoControl->diTrVerbose];
		res = res /.  dr -> ds ;
		FCPrint[3, "DiracTrick: diracTrickEval: After ds ", res, FCDoControl->diTrVerbose];
		res = res /.  dr -> DOT ;
		FCPrint[3, "DiracTrick: diracTrickEval: After dr ", res, FCDoControl->diTrVerbose];


		If[	insideDiracTrace && res=!=0,
			time=AbsoluteTime[];
			FCPrint[1, "DiracTrick: diracTrickEval: Applying diracTraceSimplify again ", FCDoControl->diTrVerbose];
			res = ReplaceAll[diracTraceSimplify/@((res/. DOT -> holdDOT)+null1+null2),{diracTraceSimplify[null1|null2]->0,
				diracTraceSimplify[c_ d_holdDOT ]/; NonCommFreeQ[c]:> c diracTraceSimplify[d]}];
			res = res /. diracTraceSimplify[holdDOT[x__]] :> diracTraceSimplify[x]/. diracTraceSimplify ->DOT /. holdDOT->DOT;
			FCPrint[1,"DiracTrace: diracTrickEval: diracTraceSimplify done, timing: ", N[AbsoluteTime[] - time, 4], FCDoControl->diTrVerbose];
			FCPrint[3, "DiracTrick: diracTrickEval: After diracTraceSimplify ", res, FCDoControl->diTrVerbose]
		];

		FCPrint[1, "DiracTrick: diracTrickEval: Leaving.", FCDoControl->diTrVerbose];
		FCPrint[3, "DiracTrick: diracTrickEval: Leaving with ", res, FCDoControl->diTrVerbose];
		res
	];

ds[x___] :=
	If[ $BreitMaison,
		dsBM[x],
		dsNV[x]
	];

(*If we are not using the BM scheme, we keep the projectors as they are*)
dsNV[x___] :=
	MemSet[dsNV[x], dr[x]]/;  !$BreitMaison;

(*If we are using the BM scheme, all g^5 in the projectors should be spelled out!*)
dsBM[x___] :=
	MemSet[dsBM[x], dr[x]/.{DiracGamma[6]->(1/2 + DiracGamma[5]/2), DiracGamma[7]->(1/2 - DiracGamma[5]/2) }]/;
		Head[DiracGamma[6]]===DiracGamma && $BreitMaison;

(* drdef *)
ds[] = dr[] = 1;

dr[a___,y_ w_,b___] :=
	coneins[y ds[a,w,b]]/;(NonCommFreeQ[y]&&FreeQ[y,dr]);
dr[a___,y_ ,b___] :=
	coneins[y ds[a,b] ] /;(NonCommFreeQ[y]&&FreeQ[y,dr]);

(*These relations between g^5 and the projectors hold in all dimensions and all schemes*)
dr[b___,DiracGamma[5],DiracGamma[5],c___] :=
	ds[ b,c ];
dr[b___,DiracGamma[5],DiracGamma[6],c___] :=
	ds[b,DiracGamma[6],c];
dr[b___,DiracGamma[5],DiracGamma[7],c___] :=
	-ds[b,DiracGamma[7],c];
dr[b___,DiracGamma[6], DiracGamma[5], c___] :=
	ds[b,DiracGamma[6],c];
dr[b___,DiracGamma[7],DiracGamma[5],c___] :=
	-ds[b, DiracGamma[7], c];

(*These are the usual projector properties. They also hold in all schemes*)
dr[___,DiracGamma[6], DiracGamma[7], ___] :=
	0;
dr[___,DiracGamma[7], DiracGamma[6], ___] :=
	0;
dr[b___,DiracGamma[6],DiracGamma[6],c___] :=
	ds[b, DiracGamma[6], c];
dr[b___,DiracGamma[7],DiracGamma[7],c___] :=
	ds[b, DiracGamma[7], c];
dr[b___,DiracGamma[6]+DiracGamma[7],c___] :=
	ds[b, c];


(*If we have a projector behind a gamma matrix, we should anticommute them.
	This holds only in four dimensions or in a naive gamma5 scheme *)

dr[b___, DiracGamma[6],DiracGamma[x_[c__],dim_ : 4],d___ ] :=
	ds[b, DiracGamma[x[c], dim], DiracGamma[7],d ]/; (!$BreitMaison || dim === 4);

dr[b___, DiracGamma[7],DiracGamma[x_[c__],dim_ : 4],d___ ] :=
	ds[b, DiracGamma[x[c], dim], DiracGamma[6],d ]/; (!$BreitMaison || dim === 4);

dr[b___, (cc1_ + cc2_. DiracGamma[6]),DiracGamma[x_[c__],dim_ : 4],d___ ] :=
	ds[b, DiracGamma[x[c], dim], (cc1 + cc2 DiracGamma[7]),d ]/; (!$BreitMaison || dim === 4) && NonCommFreeQ[{cc1,cc2}];

dr[b___, (cc1_ + cc2_. DiracGamma[7]),DiracGamma[x_[c__],dim_ : 4],d___ ] :=
	ds[b, DiracGamma[x[c], dim], (cc1 + cc2 DiracGamma[6]),d ]/; (!$BreitMaison || dim === 4) && NonCommFreeQ[{cc1,cc2}];

dr[b___, (cc1_. DiracGamma[6] + cc2_. DiracGamma[7]),DiracGamma[x_[c__],dim_ : 4],d___ ] :=
	ds[b, DiracGamma[x[c], dim], (cc1 DiracGamma[7] + cc2 DiracGamma[6]),d ]/; (!$BreitMaison || dim === 4) && NonCommFreeQ[{cc1,cc2}];

(*In 4 dimensions g^5 always anticommutes with all the other gamma matrices*)
dr[b___,DiracGamma[5],c:DiracGamma[_[_]].. ,d___] :=
	(-1)^Length[{c}] ds[ b,c,DiracGamma[5],d];

(*In D dimensions it depends on the scheme we are using!
	Careful: The following three definitions are scheme dependent!!! *)

(*In the native scheme, g^5 anticommutes with all the other gamma matrices in all dimensions*)
dr[b___,DiracGamma[5],c:DiracGamma[_[__],_].. ,d___] :=
	( (-1)^Length[{c}] ds[ b,c,DiracGamma[5],d ] ) /;!$BreitMaison;

(*In the BM scheme, the anticommutator is not zero*)
dr[b___,DiracGamma[5],DiracGamma[x_[y__],d_Symbol -4] ,f___] :=
	(ds[ b,DiracGamma[x[y],d-4],DiracGamma[5],f ] ) /; ($BreitMaison && !$Larin);

dr[b___,DiracGamma[5],DiracGamma[x_[y__],d_Symbol] ,f___] :=
	( 2 ds[b,DiracGamma[x[y],d-4],DiracGamma[5],f] -
		ds[b,DiracGamma[x[y],d],DiracGamma[5],f] ) /; ($BreitMaison && !$Larin);


(* o.k., some 4 years after the proposal of M.B., here it is: *)

(* The following relations are true only in the naive g^5 schemes or
if all the involved gamma matrices are four dimensional. They are not
valid for the non-naive schemes. Actually, they are even not applicable
there, since in non-naive schemes all the projects must be written out
explicitly in terms of g^5.
 *)

(* ------------------------------------------------------------------------ *)

diracTraceSimplify[] :=
	1;

diracTraceSimplify[___,0,___] :=
	0;

(* Trace cyclicity*)
diracTraceSimplify[b___,di_,c__] :=
	diracTraceSimplify[c,b, di]/; !FreeQ2[{di},{DiracGamma[5],DiracGamma[6],DiracGamma[7]}] &&
	FreeQ2[{b,c},{DiracGamma[5],DiracGamma[6],DiracGamma[7]}];

diracTraceSimplify[DiracGamma[(a:5|6|7)],b___,DiracGamma[(a:5|6|7)]] :=
	diracTraceSimplify[b];

diracTraceSimplify[DiracGamma[6],___,DiracGamma[7]] :=
	0;

diracTraceSimplify[DiracGamma[7],___,DiracGamma[6]] :=
	0;

diracTraceSimplify[DiracGamma[5],b___,DiracGamma[6]] :=
	diracTraceSimplify[b,DiracGamma[6]];

diracTraceSimplify[DiracGamma[6],b___,DiracGamma[5]] :=
	diracTraceSimplify[b,DiracGamma[6]];

diracTraceSimplify[DiracGamma[5],b___,DiracGamma[7]] :=
	-diracTraceSimplify[b,DiracGamma[7]];

diracTraceSimplify[DiracGamma[7],b___,DiracGamma[5]] :=
	-diracTraceSimplify[b,DiracGamma[7]];

diracTraceSimplify[ch : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_,___],___]..] :=
	0/; OddQ[Length[{ch}]];

diracTraceSimplify[ch : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_,___],___].., DiracGamma[5|6|7]] :=
	0/; OddQ[Length[{ch}]];

diracTraceSimplify[ch : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_,___],___].., DiracGamma[5]] :=
	0/; Length[{ch}] < 4;

diracTraceSimplify[DiracGamma[_[_,___],___], DiracGamma[_[_,___],___], DiracGamma[5]] :=
	0;

diracTraceSimplify[a:DiracGamma[_[_,___],___], b:DiracGamma[_[_,___],___], DiracGamma[6|7]] :=
	diracTraceSimplify[a,b]/2;

diracTraceSimplify[DiracGamma[5]]:=
	0;

(* ------------------------------------------------------------------------ *)

commonGamma5Properties[]:=
	1;

commonGamma5Properties[___,0,___]:=
	0;

commonGamma5Properties[b___,DiracGamma[5],DiracGamma[5],c___] :=
	commonGamma5Properties[ b,c ];
commonGamma5Properties[b___,DiracGamma[5],DiracGamma[6],c___] :=
	commonGamma5Properties[b,DiracGamma[6],c];
commonGamma5Properties[b___,DiracGamma[5],DiracGamma[7],c___] :=
	-commonGamma5Properties[b,DiracGamma[7],c];
commonGamma5Properties[b___,DiracGamma[6], DiracGamma[5], c___] :=
	commonGamma5Properties[b,DiracGamma[6],c];
commonGamma5Properties[b___,DiracGamma[7],DiracGamma[5],c___] :=
	-commonGamma5Properties[b, DiracGamma[7], c];

commonGamma5Properties[___,DiracGamma[6], DiracGamma[7], ___] :=
	0;
commonGamma5Properties[___,DiracGamma[7], DiracGamma[6], ___] :=
	0;
commonGamma5Properties[b___,DiracGamma[6],DiracGamma[6],c___] :=
	commonGamma5Properties[b, DiracGamma[6], c];
commonGamma5Properties[b___,DiracGamma[7],DiracGamma[7],c___] :=
	commonGamma5Properties[b, DiracGamma[7], c];
commonGamma5Properties[b___,DiracGamma[6]+DiracGamma[7],c___] :=
	commonGamma5Properties[b, c];

(* ------------------------------------------------------------------------ *)

chiralTrickAnticommutingSameDim[b___,DiracGamma[5],DiracGamma[5],c___] :=
	chiralTrickAnticommutingSameDim[ b,c ];

chiralTrickAnticommutingSameDim[b___,DiracGamma[5],DiracGamma[6],c___] :=
	chiralTrickAnticommutingSameDim[b,DiracGamma[6],c];

chiralTrickAnticommutingSameDim[b___,DiracGamma[5],DiracGamma[7],c___] :=
	-chiralTrickAnticommutingSameDim[b,DiracGamma[7],c];

chiralTrickAnticommutingSameDim[b___,DiracGamma[6], DiracGamma[5], c___] :=
	chiralTrickAnticommutingSameDim[b,DiracGamma[6],c];

chiralTrickAnticommutingSameDim[b___,DiracGamma[7],DiracGamma[5],c___] :=
	-chiralTrickAnticommutingSameDim[b, DiracGamma[7], c];

chiralTrickAnticommutingSameDim[___,DiracGamma[6], DiracGamma[7], ___] :=
	0;

chiralTrickAnticommutingSameDim[___,DiracGamma[7], DiracGamma[6], ___] :=
	0;

chiralTrickAnticommutingSameDim[b___,DiracGamma[6],DiracGamma[6],c___] :=
	chiralTrickAnticommutingSameDim[b, DiracGamma[6], c];

chiralTrickAnticommutingSameDim[b___,DiracGamma[7],DiracGamma[7],c___] :=
	chiralTrickAnticommutingSameDim[b, DiracGamma[7], c];

chiralTrickAnticommutingSameDim[b___,DiracGamma[6]+DiracGamma[7],c___] :=
	chiralTrickAnticommutingSameDim[b, c];

chiralTrickAnticommutingSameDim[b___,DiracGamma[5],c:DiracGamma[_[__],_:4].. ,d___] :=
	(-1)^Length[{c}] chiralTrickAnticommutingSameDim[ b,c,DiracGamma[5],d];

chiralTrickAnticommutingSameDim[b___, DiracGamma[5],(dd1_. (dg:DiracGamma[_[__],_:4]) + dd2_),d___ ] :=
	chiralTrickAnticommutingSameDim[b,(- dd1 dg + dd2), DiracGamma[5],d ]/; NonCommFreeQ[{dd1,dd2}];


chiralTrickAnticommutingSameDim[b___, (cc1_. DiracGamma[6] + cc2_. DiracGamma[7]),(dd1_. DiracGamma[6] + dd2_. DiracGamma[7]),d___ ] :=
	chiralTrickAnticommutingSameDim[b, (cc1 dd1 DiracGamma[6] + cc2 dd2 DiracGamma[7]),d ]/; NonCommFreeQ[{cc1,cc2,dd1,dd2}];

chiralTrickAnticommutingSameDim[b___, (cc1_ + cc2_. DiracGamma[6]),DiracGamma[x_[c__],dim_ : 4],d___ ] :=
	chiralTrickAnticommutingSameDim[b, DiracGamma[x[c], dim], (cc1 + cc2 DiracGamma[7]),d ]/; NonCommFreeQ[{cc1,cc2}];

chiralTrickAnticommutingSameDim[b___, (cc1_ + cc2_. DiracGamma[7]),DiracGamma[x_[c__],dim_ : 4],d___ ] :=
	chiralTrickAnticommutingSameDim[b, DiracGamma[x[c], dim], (cc1 + cc2 DiracGamma[6]),d ]/; NonCommFreeQ[{cc1,cc2}];

chiralTrickAnticommutingSameDim[b___, (cc1_. DiracGamma[6] + cc2_. DiracGamma[7]),DiracGamma[x_[c__],dim_ : 4],d___ ] :=
	chiralTrickAnticommutingSameDim[b, DiracGamma[x[c], dim], (cc1 DiracGamma[7] + cc2 DiracGamma[6]),d ]/; NonCommFreeQ[{cc1,cc2}];

chiralTrickAnticommutingSameDim[b___, (cc1_ + cc2_. DiracGamma[6]),(dd1_. DiracGamma[x_[c__],dim_ : 4] + dd2_),d___ ] :=
	chiralTrickAnticommutingSameDim[b,(dd1 DiracGamma[x[c], dim] + dd2), (cc1 + cc2 DiracGamma[7]),d ]/; NonCommFreeQ[{cc1,cc2,dd1,dd2}];

chiralTrickAnticommutingSameDim[b___, (cc1_ + cc2_. DiracGamma[7]),(dd1_. DiracGamma[x_[c__],dim_ : 4] + dd2_),d___ ] :=
	chiralTrickAnticommutingSameDim[b,(dd1 DiracGamma[x[c], dim] + dd2), (cc1 + cc2 DiracGamma[6]),d ]/; NonCommFreeQ[{cc1,cc2,dd1,dd2}];

chiralTrickAnticommutingSameDim[b___, (cc1_. DiracGamma[6] + cc2_. DiracGamma[7]),(dd1_. DiracGamma[x_[c__],dim_ : 4] + dd2_),d___ ] :=
	chiralTrickAnticommutingSameDim[b,(dd1 DiracGamma[x[c], dim] + dd2), (cc1 DiracGamma[7] + cc2 DiracGamma[6]),d ]/; NonCommFreeQ[{cc1,cc2,dd1,dd2}];

chiralTrickAnticommutingSameDim[b___, DiracGamma[7],DiracGamma[_[__], ___] + mass_, xy:DiracGamma[_[__], ___].. , DiracGamma[6], c___] :=
	mass chiralTrickAnticommutingSameDim[b, xy, DiracGamma[6], c]/; OddQ[Length[{xy}]] && NonCommFreeQ[mass];

chiralTrickAnticommutingSameDim[b___,DiracGamma[6],DiracGamma[_[__], ___] + mass_, xy:DiracGamma[_[__], ___].. , DiracGamma[7], c___] :=
	mass chiralTrickAnticommutingSameDim[b, xy, DiracGamma[7], c]/; OddQ[Length[{xy}]] && NonCommFreeQ[mass];

chiralTrickAnticommutingSameDim[b___,DiracGamma[6],DiracGamma[_[__], ___] + mass_, xy:DiracGamma[_[__], ___].. , DiracGamma[6], c___] :=
	mass chiralTrickAnticommutingSameDim[b, xy, DiracGamma[6], c]/; EvenQ[Length[{xy}]] && NonCommFreeQ[mass];

chiralTrickAnticommutingSameDim[b___,DiracGamma[7],DiracGamma[_[__], ___] + mass_, xy:DiracGamma[_[__], ___].. , DiracGamma[7], c___] :=
	mass chiralTrickAnticommutingSameDim[b, xy, DiracGamma[7], c]/; EvenQ[Length[{xy}]] && NonCommFreeQ[mass];

chiralTrickAnticommutingSameDim[b___,DiracGamma[6],DiracGamma[_[__], ___] + mass_, DiracGamma[6], c___] :=
	mass chiralTrickAnticommutingSameDim[b, DiracGamma[6], c]/; NonCommFreeQ[mass];

chiralTrickAnticommutingSameDim[b___,DiracGamma[7],DiracGamma[_[__], ___] + mass_, DiracGamma[7], c___] :=
	mass chiralTrickAnticommutingSameDim[b, DiracGamma[7], c]/; NonCommFreeQ[mass];

chiralTrickAnticommutingSameDim[b___,DiracGamma[6],(dg:DiracGamma[_[__], ___]) + mass_, DiracGamma[7], c___] :=
	chiralTrickAnticommutingSameDim[b, dg, DiracGamma[7], c]/; NonCommFreeQ[mass];

chiralTrickAnticommutingSameDim[b___,DiracGamma[7],(dg:DiracGamma[_[__], ___]) + mass_, DiracGamma[6], c___] :=
	chiralTrickAnticommutingSameDim[b, dg, DiracGamma[6], c] /; NonCommFreeQ[mass];

chiralTrickAnticommutingSameDim[b___,DiracGamma[6],(dg:DiracGamma[_[__], ___]) + mass_, xy:DiracGamma[_[__], ___].. , DiracGamma[7], c___] :=
	chiralTrickAnticommutingSameDim[b, dg, xy, DiracGamma[7], c] /; EvenQ[Length[{xy}]] && NonCommFreeQ[mass];

chiralTrickAnticommutingSameDim[b___,DiracGamma[7],(dg:DiracGamma[_[__], ___]) + mass_, xy:DiracGamma[_[__], ___].. , DiracGamma[6], c___] :=
	chiralTrickAnticommutingSameDim[b, dg, xy, DiracGamma[6], c] /; EvenQ[Length[{xy}]] && NonCommFreeQ[mass];

chiralTrickAnticommutingSameDim[b___,DiracGamma[6],(dg:DiracGamma[_[__], ___]) + mass_, xy:DiracGamma[_[__], ___].. , DiracGamma[6], c___] :=
	chiralTrickAnticommutingSameDim[b, dg, xy, DiracGamma[6], c] /; OddQ[Length[{xy}]] && NonCommFreeQ[mass];

chiralTrickAnticommutingSameDim[b___,DiracGamma[7],(dg:DiracGamma[_[__], ___]) +  mass_,	xy:DiracGamma[_[__], ___].. , DiracGamma[7], c___] :=
	chiralTrickAnticommutingSameDim[b, dg, xy, DiracGamma[7], c] /; OddQ[Length[{xy}]] && NonCommFreeQ[mass];


(* ------------------------------------------------------------------------ *)


chiralTrick[b___,DiracGamma[5],DiracGamma[5],c___] :=
	chiralTrick[ b,c ];
chiralTrick[b___,DiracGamma[5],DiracGamma[6],c___] :=
	chiralTrick[b,DiracGamma[6],c];
chiralTrick[b___,DiracGamma[5],DiracGamma[7],c___] :=
	-chiralTrick[b,DiracGamma[7],c];
chiralTrick[b___,DiracGamma[6], DiracGamma[5], c___] :=
	chiralTrick[b,DiracGamma[6],c];
chiralTrick[b___,DiracGamma[7],DiracGamma[5],c___] :=
	-chiralTrick[b, DiracGamma[7], c];

(*These are the usual projector properties. They also hold in all schemes*)
chiralTrick[___,DiracGamma[6], DiracGamma[7], ___] :=
	0;
chiralTrick[___,DiracGamma[7], DiracGamma[6], ___] :=
	0;
chiralTrick[b___,DiracGamma[6],DiracGamma[6],c___] :=
	chiralTrick[b, DiracGamma[6], c];
chiralTrick[b___,DiracGamma[7],DiracGamma[7],c___] :=
	chiralTrick[b, DiracGamma[7], c];
chiralTrick[b___,DiracGamma[6]+DiracGamma[7],c___] :=
	chiralTrick[b, c];

chiralTrick[b___,DiracGamma[5],c:DiracGamma[_[_,_:4],_:4].. ,d___] :=
	(-1)^Length[{c}] chiralTrick[ b,c,DiracGamma[5],d]/; (!$BreitMaison || FCGetDimensions[{c}]==={4}) && Length[FCGetDimensions[{c}]]===1;

chiralTrick[b___, DiracGamma[5],(dd1_. DiracGamma[x_[c__],dim_ : 4] + dd2_),d___ ] :=
	chiralTrick[b,(- dd1 DiracGamma[x[c], dim] + dd2), DiracGamma[5],d ]/; (!$BreitMaison || dim === 4) && NonCommFreeQ[{dd1,dd2}];


chiralTrick[b___, (cc1_. DiracGamma[6] + cc2_. DiracGamma[7]),(dd1_. DiracGamma[6] + dd2_. DiracGamma[7]),d___ ] :=
	chiralTrick[b, (cc1 dd1 DiracGamma[6] + cc2 dd2 DiracGamma[7]),d ]/; NonCommFreeQ[{cc1,cc2,dd1,dd2}];

chiralTrick[b___, (cc1_ + cc2_. DiracGamma[6]),DiracGamma[x_[c__],dim_ : 4],d___ ] :=
	chiralTrick[b, DiracGamma[x[c], dim], (cc1 + cc2 DiracGamma[7]),d ]/; (!$BreitMaison || dim === 4) && NonCommFreeQ[{cc1,cc2}];

chiralTrick[b___, (cc1_ + cc2_. DiracGamma[7]),DiracGamma[x_[c__],dim_ : 4],d___ ] :=
	chiralTrick[b, DiracGamma[x[c], dim], (cc1 + cc2 DiracGamma[6]),d ]/; (!$BreitMaison || dim === 4) && NonCommFreeQ[{cc1,cc2}];

chiralTrick[b___, (cc1_. DiracGamma[6] + cc2_. DiracGamma[7]),DiracGamma[x_[c__],dim_ : 4],d___ ] :=
	chiralTrick[b, DiracGamma[x[c], dim], (cc1 DiracGamma[7] + cc2 DiracGamma[6]),d ]/; (!$BreitMaison || dim === 4) && NonCommFreeQ[{cc1,cc2}];

chiralTrick[b___, (cc1_ + cc2_. DiracGamma[6]),(dd1_. DiracGamma[x_[c__],dim_ : 4] + dd2_),d___ ] :=
	chiralTrick[b,(dd1 DiracGamma[x[c], dim] + dd2), (cc1 + cc2 DiracGamma[7]),d ]/; (!$BreitMaison || dim === 4) && NonCommFreeQ[{cc1,cc2,dd1,dd2}];

chiralTrick[b___, (cc1_ + cc2_. DiracGamma[7]),(dd1_. DiracGamma[x_[c__],dim_ : 4] + dd2_),d___ ] :=
	chiralTrick[b,(dd1 DiracGamma[x[c], dim] + dd2), (cc1 + cc2 DiracGamma[6]),d ]/; (!$BreitMaison || dim === 4) && NonCommFreeQ[{cc1,cc2,dd1,dd2}];

chiralTrick[b___, (cc1_. DiracGamma[6] + cc2_. DiracGamma[7]),(dd1_. DiracGamma[x_[c__],dim_ : 4] + dd2_),d___ ] :=
	chiralTrick[b,(dd1 DiracGamma[x[c], dim] + dd2), (cc1 DiracGamma[7] + cc2 DiracGamma[6]),d ]/; (!$BreitMaison || dim === 4) && NonCommFreeQ[{cc1,cc2,dd1,dd2}];

chiralTrick[b___,DiracGamma[7],DiracGamma[_[__], dim1_ : 4] + (n_. mass_),
	xy:DiracGamma[_[__], dim2_ : 4].. , DiracGamma[6], c___] :=
	(n mass chiralTrick[b, xy, DiracGamma[6], c])/; NumberQ[n] &&
		OddQ[Length[{xy}]] && NonCommFreeQ[mass] && (!$BreitMaison || (dim1===4 && dim2===4));

chiralTrick[b___,DiracGamma[6],DiracGamma[_[__], dim1_ : 4] + (n_. mass_ ),
	xy:DiracGamma[_[__], dim2_ : 4].. , DiracGamma[7], c___] :=
	(n mass chiralTrick[b, xy, DiracGamma[7], c]) /; NumberQ[n] &&
		OddQ[Length[{xy}]] && NonCommFreeQ[mass] && (!$BreitMaison || (dim1===4 && dim2===4));

chiralTrick[b___,DiracGamma[6],DiracGamma[_[__], dim1_ : 4] + (n_. mass_ ),
	xy:DiracGamma[_[__], dim2_ : 4].. , DiracGamma[6], c___] :=
	(n mass chiralTrick[b, xy, DiracGamma[6], c]) /; NumberQ[n] &&
		EvenQ[Length[{xy}]] && NonCommFreeQ[mass] && (!$BreitMaison || (dim1===4 && dim2===4));

chiralTrick[b___,DiracGamma[7],DiracGamma[_[__], dim1_ : 4] + (n_. mass_ ),
	xy:DiracGamma[_[__], dim2_ : 4].. , DiracGamma[7], c___] :=
	(n mass chiralTrick[b, xy, DiracGamma[7], c]) /; NumberQ[n] &&
		EvenQ[Length[{xy}]] && NonCommFreeQ[mass] && (!$BreitMaison || (dim1===4 && dim2===4));

chiralTrick[b___,DiracGamma[6],DiracGamma[_[__], dim_ : 4] + (n_. mass_ ),
	DiracGamma[6], c___] :=
	(n mass chiralTrick[b, DiracGamma[6], c] )/; NumberQ[n] && NonCommFreeQ[mass] && (!$BreitMaison || dim===4);

chiralTrick[b___,DiracGamma[7],DiracGamma[_[__], dim_ : 4] + (n_. mass_ ),
	DiracGamma[7], c___] :=
	(n mass chiralTrick[b, DiracGamma[7], c] )/; NumberQ[n] && NonCommFreeQ[mass] && (!$BreitMaison || dim===4);

chiralTrick[b___,DiracGamma[6],DiracGamma[v_[w__], dim_ : 4] + (n_. mass_ ),
	DiracGamma[7], c___] :=
	chiralTrick[b, DiracGamma[v[w], dim], DiracGamma[7], c] /; NumberQ[n] &&
		NonCommFreeQ[mass] && (!$BreitMaison || dim===4);

chiralTrick[b___,DiracGamma[7],DiracGamma[v_[w__], dim_ : 4] + (n_. mass_),
	DiracGamma[6], c___] :=
	chiralTrick[b, DiracGamma[v[w], dim], DiracGamma[6], c] /; NumberQ[n] &&
		NonCommFreeQ[mass] && (!$BreitMaison || dim===4);

chiralTrick[b___,DiracGamma[6],DiracGamma[v_[w__], dim1_ : 4] + (n_. mass_ ),
	xy:DiracGamma[_[__], dim2_ : 4].. , DiracGamma[7], c___] :=
	chiralTrick[b, DiracGamma[v[w], dim1], xy, DiracGamma[7], c] /; NumberQ[n] &&
			EvenQ[Length[{xy}]] && NonCommFreeQ[mass] && (!$BreitMaison || (dim1===4 && dim2===4));

chiralTrick[b___,DiracGamma[7],DiracGamma[v_[w__], dim1_ : 4] + (n_. mass_ ),
	xy:DiracGamma[_[__], dim2_ : 4].. , DiracGamma[6], c___] :=
	chiralTrick[b, DiracGamma[v[w], dim1], xy, DiracGamma[6], c] /; NumberQ[n] &&
			EvenQ[Length[{xy}]] && NonCommFreeQ[mass] && (!$BreitMaison || (dim1===4 && dim2===4));

chiralTrick[b___,DiracGamma[6],DiracGamma[v_[w__], dim1_ : 4] + (n_. mass_ ),
	xy:DiracGamma[_[__], dim2_ : 4].. , DiracGamma[6], c___] :=
	chiralTrick[b, DiracGamma[v[w], dim1], xy, DiracGamma[6], c] /; NumberQ[n] &&
			OddQ[Length[{xy}]] && NonCommFreeQ[mass]  && (!$BreitMaison || (dim1===4 && dim2===4));

chiralTrick[b___,DiracGamma[7],DiracGamma[v_[w__], dim1_ : 4] + (n_. mass_),
	xy:DiracGamma[_[__], dim2_ : 4].. , DiracGamma[7], c___] :=
	chiralTrick[b, DiracGamma[v[w], dim1], xy, DiracGamma[7], c] /; NumberQ[n] &&
			OddQ[Length[{xy}]] && NonCommFreeQ[mass] && (!$BreitMaison || (dim1===4 && dim2===4));

(* Simplification for g^mu ... g_mu where the first and the last
	matrix are in different dimensions                                         *)
(* ------------------------------------------------------------------------ *)

(* D and 4  -> 4 *)
drS[ b___, DiracGamma[LorentzIndex[c_, dimD_Symbol], dimD_Symbol], d:DiracGamma[__].. ,
	DiracGamma[LorentzIndex[c_]], f___ ] :=
	drS[b, DiracGamma[LorentzIndex[c]], d, DiracGamma[LorentzIndex[c]], f];

(* 4 and D -> 4 *)
drS[ b___, DiracGamma[LorentzIndex[c_]], d:DiracGamma[__].. ,
	DiracGamma[LorentzIndex[c_, dimD_Symbol], dimD_Symbol], f___ ] :=
	drS[b, DiracGamma[LorentzIndex[c]], d, DiracGamma[LorentzIndex[c]], f];

(* D and D-4 -> D-4 *)
drS[ b___, DiracGamma[LorentzIndex[c_, dimD_Symbol], dimD_Symbol], d:DiracGamma[__].. ,
	DiracGamma[LorentzIndex[c_, dimD_Symbol-4], dimD_Symbol-4], f___ ] :=
	drS[b,DiracGamma[LorentzIndex[c, dimD-4], dimD-4],
	d,DiracGamma[LorentzIndex[c, dimD-4], dimD-4], f];

(* D-4 and D -> D-4 *)
drS[ b___, DiracGamma[LorentzIndex[c_, dimD_Symbol-4], dimD_Symbol-4], d:DiracGamma[__].. ,
			DiracGamma[LorentzIndex[c_, dimD_Symbol],dimD_Symbol],f___ ] :=
	drS[b,DiracGamma[LorentzIndex[c, dimD-4], dimD-4],
	d, DiracGamma[LorentzIndex[c, dimD-4], dimD-4],f];

(* 4 and D-4 -> 0 *)
drS[ ___, DiracGamma[LorentzIndex[c_, dimD_Symbol-4], dimD_Symbol-4], DiracGamma[__].. ,
			DiracGamma[LorentzIndex[c_]], ___ ] :=
	0;

(* D-4 and 4 -> 0 *)
drS[ ___, DiracGamma[LorentzIndex[c_]], DiracGamma[__].. ,
			DiracGamma[LorentzIndex[c_, dimD_Symbol-4], dimD_Symbol-4], ___ ] :=
	0;

(* Contractions of neighbouring Dirac matrices in D, 4 and D-4 dimensions     *)
(* ------------------------------------------------------------------------ *)

dr[b___,DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_:  4],
		DiracGamma[LorentzIndex[c_, dim2_ : 4], dim2_: 4], d___] :=
	(PairContract[LorentzIndex[c, dim1],LorentzIndex[c, dim2]]/. PairContract->Pair) ds[ b,d ];

(* Simplifications for g^mu g^nu_1 ... g^nu_n g_mu where g^mu is in 4 and
	g^nu_i are in D-4 dimensions or vice versa.                                *)
(* ------------------------------------------------------------------------ *)

(* 4, (... D-4 ... ), 4 *)
dr[b___ , DiracGamma[LorentzIndex[c_]],
			ch : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_, dim_Symbol-4] , dim_Symbol-4]..,
			DiracGamma[LorentzIndex[c_]], d___] :=
	4 (-1)^Length[{ch}] ds[b,ch, d];

(* D-4, (... 4 ... ), D-4 *)
dr[b___ , DiracGamma[LorentzIndex[c_, dim_Symbol-4], dim_Symbol-4],
			ch : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_]]..,
			DiracGamma[LorentzIndex[c_, dim_Symbol-4], dim_Symbol-4], d___] :=
	(dim - 4) (-1)^Length[{ch}] ds[b,ch, d];

(* Simplification for g^mu g^nu_1 ... g^nu_n g_mu where g^mu is in D and
	g^nu_i are in 4 dimensions. Applies for n>4, since for n<=4 we have
	explicit expressions in the code                                        *)
(* ------------------------------------------------------------------------ *)

dr[b___ , DiracGamma[LorentzIndex[c_, dim_Symbol], dim_Symbol],
			ch : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_]]..,
			DiracGamma[LorentzIndex[c_, dim_Symbol], dim_Symbol], d___] :=
	ds[b,DiracGamma[LorentzIndex[c]], ch, DiracGamma[LorentzIndex[c]], d] +
	(dim - 4) (-1)^Length[{ch}] ds[b,ch, d]/; Length[{ch}]>4;

(* Simplification for g^mu g^nu_1 ... g^nu_n g_mu where g^mu is in D and
	g^nu_i are in D-4 dimensions. Applies for n>4, since for n<=4 we have
	explicit expressions in the code                                        *)
(* ------------------------------------------------------------------------ *)

dr[b___ , DiracGamma[LorentzIndex[c_, dim_Symbol], dim_Symbol],
			ch : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_,
			dim_Symbol-4],dim_Symbol-4]..,
			DiracGamma[LorentzIndex[c_, dim_Symbol], dim_Symbol], d___] :=
	ds[b,DiracGamma[LorentzIndex[c,dim-4],dim-4], ch, DiracGamma[LorentzIndex[c,dim-4],dim-4], d] +
	4 (-1)^Length[{ch}] ds[b,ch, d]/; Length[{ch}]>4;


(* Evaluation of g^mu g^nu g_mu for Dirac matrices in different
	dimensions                                                                *)
(* ------------------------------------------------------------------------ *)


(* D, D, D or 4, 4, 4 or D-4, D-4, D-4
	or D, D-4, D or D, 4, D *)
dr[b___ , DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4],
			DiracGamma[(x: LorentzIndex | ExplicitLorentzIndex | Momentum)[y_, dim2_ : 4] ,dim2_ : 4],
			DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4], d___] :=
	(2 - dim1) ds[b,DiracGamma[x[y, dim2], dim2], d]/;
					(dim1===dim2 || dim2 === dim1-4 || dim2 ===4) &&
					MatchQ[dim1, _Symbol | _Symbol-4 | 4 ] &&
					MatchQ[dim2, _Symbol | _Symbol-4 | 4 ];

(* D-4, D, D-4 or 4, D, 4 *)
dr[b___ , DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4],
			DiracGamma[(x: LorentzIndex | ExplicitLorentzIndex | Momentum)[y_, dim2_Symbol], dim2_Symbol],
			DiracGamma[LorentzIndex[c_, dim1_ : 4],  dim1_ : 4], d___] :=
	- dim1 ds[b,DiracGamma[x[y,dim2],dim2],d] +
	2 ds[b,DiracGamma[x[y,dim1],dim1],d]/; (dim1 === dim2-4 || dim1 ===4);

(* Evaluation of g^mu g^nu g^rho g_mu for Dirac matrices in different
	dimensions                                                                *)
(* ------------------------------------------------------------------------ *)


(* D, D, D, D or 4, 4, 4, 4 or D-4, D-4, D-4, D-4
	or D, D-4, D-4, D or D, 4, 4, D *)
dr[b___ , DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4],
			DiracGamma[(x1: LorentzIndex | ExplicitLorentzIndex | Momentum)[y1_, dim2_ : 4] ,dim2_ : 4],
			DiracGamma[(x2: LorentzIndex | ExplicitLorentzIndex | Momentum)[y2_, dim2_ : 4] ,dim2_ : 4],
			DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4], d___] :=
	(dim1 - 4) ds[b,DiracGamma[x1[y1, dim2], dim2],
					DiracGamma[x2[y2, dim2], dim2], d] +
					4 ds[b,Pair[x1[y1,dim2],x2[y2,dim2]], d]/;
					(dim1===dim2 || dim2 === dim1-4 || dim2 ===4) &&
					MatchQ[dim1, _Symbol | _Symbol-4 | 4 ] &&
					MatchQ[dim2, _Symbol | _Symbol-4 | 4 ];

(* D-4, D, D, D-4 or 4, D, D, 4 *)
dr[b___ , DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4],
			DiracGamma[(x1: LorentzIndex | ExplicitLorentzIndex | Momentum)[y1_, dim2_Symbol], dim2_Symbol],
			DiracGamma[(x2: LorentzIndex | ExplicitLorentzIndex | Momentum)[y2_, dim2_Symbol], dim2_Symbol],
			DiracGamma[LorentzIndex[c_, dim1_: 4], dim1_ : 4], d___] :=
	dim1 ds[b,DiracGamma[x1[y1, dim2], dim2],DiracGamma[x2[y2, dim2], dim2], d] -
	2 ds[b,DiracGamma[x1[y1, dim1], dim1],DiracGamma[x2[y2, dim2], dim2], d] +
	2 ds[b,DiracGamma[x2[y2, dim1], dim1],DiracGamma[x1[y1, dim2], dim2], d]/;
	(dim1 === dim2-4 || dim1 ===4);


(* Evaluation of g^mu g^nu g^rho g^sigma g_mu for Dirac matrices in different
	dimensions                                                                *)
(* ------------------------------------------------------------------------ *)

(* D, D, D, D, D or 4, 4, 4, 4, 4 or D-4, D-4, D-4, D-4, D-4
	or D, D-4, D-4, D-4, D or D, 4, 4, 4, D *)
dr[b___ , DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4],
			DiracGamma[(x1: LorentzIndex | ExplicitLorentzIndex | Momentum)[y1_, dim2_ : 4] , dim2_ : 4],
			DiracGamma[(x2: LorentzIndex | ExplicitLorentzIndex | Momentum)[y2_, dim2_ : 4] , dim2_ : 4],
			DiracGamma[(x3: LorentzIndex | ExplicitLorentzIndex | Momentum)[y3_, dim2_ : 4] , dim2_ : 4],
			DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4], d___] :=
	-(dim1 - 4) ds[b, DiracGamma[x1[y1, dim2], dim2],
						DiracGamma[x2[y2, dim2], dim2],
						DiracGamma[x3[y3, dim2], dim2], d] -
					2 ds[b, DiracGamma[x3[y3, dim2], dim2],
							DiracGamma[x2[y2, dim2], dim2],
							DiracGamma[x1[y1, dim2], dim2], d]/;
							(dim1===dim2 || dim2 === dim1-4 || dim2 ===4) &&
							MatchQ[dim1, _Symbol | _Symbol-4 | 4 ] &&
							MatchQ[dim2, _Symbol | _Symbol-4 | 4 ];

(* D-4, D, D, D, D-4 or 4, D, D, D, 4 *)
dr[b___ , DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4],
			DiracGamma[(x1: LorentzIndex | ExplicitLorentzIndex | Momentum)[y1_, dim2_Symbol], dim2_Symbol],
			DiracGamma[(x2: LorentzIndex | ExplicitLorentzIndex | Momentum)[y2_, dim2_Symbol], dim2_Symbol],
			DiracGamma[(x3: LorentzIndex | ExplicitLorentzIndex | Momentum)[y3_, dim2_Symbol], dim2_Symbol],
			DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4], d___] :=
	-dim1 ds[b, DiracGamma[x1[y1, dim2], dim2],
				DiracGamma[x2[y2, dim2], dim2],
				DiracGamma[x3[y3, dim2], dim2], d] +
	2 ds[b, DiracGamma[x1[y1, dim1], dim1],
			DiracGamma[x2[y2, dim2], dim2],
			DiracGamma[x3[y3, dim2], dim2], d] -
	2 ds[b, DiracGamma[x2[y2, dim1], dim1],
			DiracGamma[x1[y1, dim2], dim2],
			DiracGamma[x3[y3, dim2], dim2], d] +
	2 ds[b, DiracGamma[x3[y3, dim1], dim1],
			DiracGamma[x1[y1, dim2], dim2],
			DiracGamma[x2[y2, dim2], dim2], d]/;
			(dim1 === dim2-4 || dim1 ===4);

(* Evaluation of g^mu g^nu g^rho g^sigma g^tau g_mu for Dirac matrices
	in different dimensions                                                    *)
(* ------------------------------------------------------------------------ *)

(* D, D, D, D, D, D or 4, 4, 4, 4, 4, 4 or D-4, D-4, D-4, D-4, D-4, D-4
	or D, D-4, D-4, D-4, D-4, D or D, 4, 4, 4, 4, D *)
dr[b___ , DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4],
			DiracGamma[(x1: LorentzIndex | ExplicitLorentzIndex | Momentum)[y1_, dim2_ : 4] , dim2_ : 4],
			DiracGamma[(x2: LorentzIndex | ExplicitLorentzIndex | Momentum)[y2_, dim2_ : 4] , dim2_ : 4],
			DiracGamma[(x3: LorentzIndex | ExplicitLorentzIndex | Momentum)[y3_, dim2_ : 4] , dim2_ : 4],
			DiracGamma[(x4: LorentzIndex | ExplicitLorentzIndex | Momentum)[y4_, dim2_ : 4] , dim2_ : 4],
			DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4], d___] :=
	(dim1 - 4) ds[b, DiracGamma[x1[y1, dim2], dim2],
					DiracGamma[x2[y2, dim2], dim2],
					DiracGamma[x3[y3, dim2], dim2],
					DiracGamma[x4[y4, dim2], dim2], d] +
					2 ds[b, DiracGamma[x3[y3, dim2], dim2],
							DiracGamma[x2[y2, dim2], dim2],
							DiracGamma[x1[y1, dim2], dim2],
							DiracGamma[x4[y4, dim2], dim2], d] +
				2 ds[b, DiracGamma[x4[y4, dim2], dim2],
							DiracGamma[x1[y1, dim2], dim2],
							DiracGamma[x2[y2, dim2], dim2],
							DiracGamma[x3[y3, dim2], dim2], d]/;
							(dim1===dim2 || dim2 === dim1-4 || dim2 ===4) &&
							MatchQ[dim1, _Symbol | _Symbol-4 | 4 ] &&
							MatchQ[dim2, _Symbol | _Symbol-4 | 4 ];

(* D-4, D, D, D, D, D-4 or 4, D, D, D, D, 4 *)
dr[b___ , DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4],
			DiracGamma[(x1: LorentzIndex | ExplicitLorentzIndex | Momentum)[y1_, dim2_Symbol], dim2_Symbol],
			DiracGamma[(x2: LorentzIndex | ExplicitLorentzIndex | Momentum)[y2_, dim2_Symbol], dim2_Symbol],
			DiracGamma[(x3: LorentzIndex | ExplicitLorentzIndex | Momentum)[y3_, dim2_Symbol], dim2_Symbol],
			DiracGamma[(x4: LorentzIndex | ExplicitLorentzIndex | Momentum)[y4_, dim2_Symbol], dim2_Symbol],
			DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4], d___] :=
	dim1  ds[b, DiracGamma[x1[y1, dim2], dim2],
				DiracGamma[x2[y2, dim2], dim2],
				DiracGamma[x3[y3, dim2], dim2],
				DiracGamma[x4[y4, dim2], dim2], d] -
	2 ds[b, DiracGamma[x1[y1, dim1], dim1],
			DiracGamma[x2[y2, dim2], dim2],
			DiracGamma[x3[y3, dim2], dim2],
			DiracGamma[x4[y4, dim2], dim2], d] +
	2 ds[b, DiracGamma[x2[y2, dim1], dim1],
			DiracGamma[x1[y1, dim2], dim2],
			DiracGamma[x3[y3, dim2], dim2],
			DiracGamma[x4[y4, dim2], dim2], d] -
	2 ds[b, DiracGamma[x3[y3, dim1], dim1],
			DiracGamma[x1[y1, dim2], dim2],
			DiracGamma[x2[y2, dim2], dim2],
			DiracGamma[x4[y4, dim2], dim2], d] +
	2 ds[b, DiracGamma[x4[y4, dim1], dim1],
			DiracGamma[x1[y1, dim2], dim2],
			DiracGamma[x2[y2, dim2], dim2],
			DiracGamma[x3[y3, dim2], dim2], d]/;
			(dim1 === dim2-4 || dim1 ===4);

(* Evaluation of a string of 4 dimensional Dirac matrices
	g^mu g^nu_1 ... g^nu_i g_mu  -> -2 g^nu_i ... g^nu_1,
	where i is odd *)
dr[ b___,  DiracGamma[LorentzIndex[c_]],
		ch : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_]]..,
		DiracGamma[LorentzIndex[c_]], f___ ] :=
	-2 ds @@ Join[ {b},Reverse[{ch}],{f} ] /; OddQ[Length[{ch}]];


(* Evaluation of a string of 4 dimensional Dirac matrices
	g^mu g^nu_1 ... g^nu_i g_mu  ->
	2 g^nu_i-1 ... g^nu_1 g^nu_i + 2 g^nu_i g^nu_1 ... g^nu_i-1,
	where i is even *)
dr[ b___,  DiracGamma[LorentzIndex[c_]],
		ch : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_]]..,
		end : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_]],
		DiracGamma[LorentzIndex[c_]], f___ ] :=
	( 2 ds @@ Join[ {b},Reverse[{ch}],{end}, {f}] +
	2 ds[ b,end,ch,f ]
	)/; OddQ[Length[{ch}]];

(* Slash(p).Slash(p), where both objects have the same dimension *)
dr[b___,DiracGamma[Momentum[c_, dim_ : 4], dim_ : 4],
		DiracGamma[Momentum[c_, dim_ : 4], dim_ : 4],d___ ] :=
	scev[Momentum[c,dim],Momentum[c,dim]] ds[b,d];

(* Simplifications for Slash(p) g^nu_1 ... g^nu_n Slash(p) where the slashes
	are in 4 and g^nu_i are in D-4 dimensions or vice versa.                 *)
(* ------------------------------------------------------------------------ *)

(* 4, (... D-4 ... ), 4 *)
dr[b___ , DiracGamma[Momentum[c_]],
			ch : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_, dim_Symbol-4] , dim_Symbol-4]..,
			DiracGamma[Momentum[c_]], d___] :=
	(-1)^Length[{ch}] scev[Momentum[c],Momentum[c]] ds[b,ch, d];

(* D-4, (... 4 ... ), D-4 *)
dr[b___ , DiracGamma[Momentum[c_, dim_Symbol-4], dim_Symbol-4],
			ch : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_]]..,
			DiracGamma[Momentum[c_, dim_Symbol-4], dim_Symbol-4], d___] :=
	(-1)^Length[{ch}] scev[Momentum[c, dim-4],Momentum[c, dim-4]] ds[b,ch, d];

(* Simplification for Slash(p) g^nu_1 ... g^nu_n Slash(p) where the slashes
	are in D and g^nu_i are in 4 dimensions. This applies for n>1.           *)
(* ------------------------------------------------------------------------ *)

dr[b___ , DiracGamma[Momentum[c_, dim_Symbol], dim_Symbol],
			ch : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_]]..,
			DiracGamma[Momentum[c_, dim_Symbol], dim_Symbol], d___] :=
	ds[b,DiracGamma[Momentum[c]], ch, DiracGamma[Momentum[c]], d] +
	(-1)^Length[{ch}] scev[Momentum[c, dim-4],Momentum[c, dim-4]] ds[b,ch, d]/; Length[{ch}]>1;

(* Simplification for Slash(p) g^nu_1 ... g^nu_n Slash(p) where the slashes are
	in D and g^nu_i are in D-4 dimensions. This applies for n>1.             *)
(* ------------------------------------------------------------------------ *)

dr[b___ , DiracGamma[Momentum[c_, dim_Symbol], dim_Symbol],
			ch : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_,
			dim_Symbol-4],dim_Symbol-4]..,
			DiracGamma[Momentum[c_, dim_Symbol], dim_Symbol], d___] :=
	ds[b,DiracGamma[Momentum[c,dim-4],dim-4], ch, DiracGamma[Momentum[c,dim-4],dim-4], d] +
	(-1)^Length[{ch}] scev[Momentum[c],Momentum[c]]  ds[b,ch, d]/; Length[{ch}]>1;


(* Evaluation of Slash(p) g^nu Slash(p) for Dirac matrices in different
	dimensions                                                               *)
(* ------------------------------------------------------------------------ *)

dr[b___ , DiracGamma[Momentum[c_, dim1_ : 4], dim1_ : 4],
		DiracGamma[(x: LorentzIndex | ExplicitLorentzIndex | Momentum)[y_, dim2_ : 4] ,dim2_ : 4],
		DiracGamma[Momentum[c_, dim1_ : 4], dim1_ : 4], d___] :=
	- scev[Momentum[c,dim1],Momentum[c,dim1]] ds[b,DiracGamma[x[y, dim2], dim2], d] +
	2 ds[b, Pair[Momentum[c,dim1],x[y,dim2]], DiracGamma[Momentum[c, dim1], dim1], d]/;
					(dim1===dim2 || dim2 === dim1-4 || dim2 ===4 || dim1 === dim2-4 || dim1 ===4) &&
					MatchQ[dim1, _Symbol | _Symbol-4 | 4 ] &&
					MatchQ[dim2, _Symbol | _Symbol-4 | 4 ];

(* #################################################################### *)
(*                             Main33a                                 *)
(* #################################################################### *)

(*Properties of the charge conjugation matrix for spinors. *)

dr[ a___, ChargeConjugationMatrix, ChargeConjugationMatrix, b___ ] :=
	-dr[a, b];
dr[ a___, ChargeConjugationMatrix, DiracGamma[5], b___ ] :=
	dr[a, DiracGammaT[5], ChargeConjugationMatrix, b];
dr[ a___, ChargeConjugationMatrix, DiracGamma[6], b___ ] :=
	dr[a, DiracGammaT[6], ChargeConjugationMatrix, b];
dr[ a___, ChargeConjugationMatrix, DiracGamma[7], b___ ] :=
	dr[a, DiracGammaT[7], ChargeConjugationMatrix, b];
dr[ a___, ChargeConjugationMatrix, DiracGamma[x_], b___ ] :=
	-dr[a, DiracGammaT[x], ChargeConjugationMatrix, b] /; !NumberQ[x];
dr[ a___, ChargeConjugationMatrix, DiracGammaT[x_], b___ ] :=
	-dr[a, DiracGamma[x], ChargeConjugationMatrix, b] /; !NumberQ[x];

(* #################################################################### *)
(*                             Main34                                 *)
(* #################################################################### *)

drCOs[x___] :=
	If[ $BreitMaison === True,
		drCOBM[x],
		drCONV[x]
	];

drCONV[x___] :=
	MemSet[drCONV[x], drCO[x]]/;  $BreitMaison === False;
drCOBM[x___] :=
	MemSet[drCOBM[x], drCO[x]]/; $BreitMaison === True;

(* Dirac contraction rules *) (*drCOdef*)

(* Simplification for g^mu g^nu_1 ... g^nu_n g_mu where all
	matrices are  in D or D-4 dimensions. Applies for n>5, since
	for n<=5 we have explicit expressions in the code. The
	formula is given in Eq 2.9 of R. Mertig, M. Boehm,
	A. Denner. Comp. Phys. Commun., 64 (1991)                *)
drCO[ b___,DiracGamma[LorentzIndex[c_,dim_],dim_],
	ch:DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_,
	dim_],dim_]..,
	DiracGamma[LorentzIndex[c_,dim_],dim_],f___ ] :=
	Block[ {iVar,jVar,len = Length[{ch}],dsTemp},
		(((-1)^len ( dim - 2 len ) dsTemp[b,ch,f] - 4 (-1)^len *
		Sum[ (-1)^(jVar-iVar) *  Pair[{ch}[[iVar,1]],
			{ch}[[jVar,1]] ]*dsTemp@@Join[{b},
			Delete[{ch}, {{iVar},{jVar}}], {f}],{iVar,1,len-1},{jVar,iVar+1,len}
		])//coneins)/.dsTemp->ds/.Pair->scev
	] /;(Length[{ch}]>4) && MatchQ[dim, _Symbol | _Symbol-4 ];


(* Simplification for Slash(p) g^nu_1 ... g^nu_n Slash(p) where all
	matrices are in D, 4 or D-4 dimensions. The
	formula is given in Eq 2.10 of R. Mertig, M. Boehm,
	A. Denner. Comp. Phys. Commun., 64 (1991)                *)
drCO[b___, DiracGamma[Momentum[c_, dim_ : 4], dim_ : 4],
			ch:DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_, dim_ : 4], dim_ : 4]..,
			DiracGamma[Momentum[c_, dim_ : 4], dim_ : 4],f___
	] :=
	Block[ {iVar, len = Length[{ch}]},
		(-1)^len scev[Momentum[c, dim],Momentum[c, dim]] ds[b,ch,f]
		+ 2 Sum[(-1)^(iVar+1) coneins[ Pair[Momentum[c, dim],{ch}[[iVar,1]] ]
				* ds@@Join[{b},Drop[{ch},{iVar, iVar}],{DiracGamma[Momentum[c, dim],dim],f}]
										],{iVar, 1,len}]
	]/;
				(Length[{ch}]>0) && MatchQ[dim, _Symbol | _Symbol-4 | 4 ];

(* g^mu g^nu_1 ... g^nu_n g_mu, where g^mu is in 4 or D-4
	and g^nu_i are in D dimensions is simplfied by repeatedly
	applying anticommuation relations. Applies for n>5,
	since for n<=5 we have explicit expressions in the code *)

drCO[b___, DiracGamma[LorentzIndex[c_, dim_Symbol-4], dim_Symbol-4],
		ch1 : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_, dim_Symbol] , dim_Symbol]..,
		ch2 : DiracGamma[(h : LorentzIndex | ExplicitLorentzIndex | Momentum)[x_, dim_Symbol] , dim_Symbol],
		DiracGamma[LorentzIndex[c_, dim_Symbol-4], dim_Symbol-4], d___] :=
	(-drCO[b, DiracGamma[LorentzIndex[c, dim-4],dim-4], ch1, DiracGamma[LorentzIndex[c, dim-4], dim-4], ch2, d]
	+ 2 drCO[b, DiracGamma[h[x,dim-4],dim-4], ch1, d] )/.drCO->ds;

drCO[b___, DiracGamma[LorentzIndex[c_]],
		ch1 : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_, dim_Symbol] , dim_Symbol]..,
		ch2 : DiracGamma[(h : LorentzIndex | ExplicitLorentzIndex | Momentum)[x_, dim_Symbol] , dim_Symbol],
		DiracGamma[LorentzIndex[c_]], d___] :=
	(-drCO[b, DiracGamma[LorentzIndex[c]], ch1, DiracGamma[LorentzIndex[c]], ch2, d]
	+ 2 drCO[b, DiracGamma[h[x]], ch1, d] )/.drCO->ds;

(* Slash(p) g^nu_1 ... g^nu_n Slash(p), where the slashes
	are in 4 or D-4 and g^nu_i are in D dimensions is simplfied
	by repeatedly applying anticommuation relations.             *)

drCO[b___, DiracGamma[Momentum[c_, dim_Symbol-4], dim_Symbol-4],
		ch1 : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_, dim_Symbol] , dim_Symbol]..,
		ch2 : DiracGamma[(h : LorentzIndex | ExplicitLorentzIndex | Momentum)[x_, dim_Symbol] , dim_Symbol],
		DiracGamma[Momentum[c_, dim_Symbol-4], dim_Symbol-4], d___] :=
	(-drCO[b, DiracGamma[Momentum[c, dim-4],dim-4], ch1, DiracGamma[Momentum[c, dim-4], dim-4], ch2, d]
	+ 2 drCO[b,Pair[Momentum[c,dim-4],h[x,dim-4]], DiracGamma[Momentum[c, dim-4],dim-4], ch1, d] )/.drCO->ds;

drCO[b___, DiracGamma[Momentum[c_]],
		ch1 : DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_, dim_Symbol] , dim_Symbol]..,
		ch2 : DiracGamma[(h : LorentzIndex | ExplicitLorentzIndex | Momentum)[x_, dim_Symbol] , dim_Symbol],
		DiracGamma[Momentum[c_]], d___] :=
	(-drCO[b, DiracGamma[Momentum[c]], ch1, DiracGamma[Momentum[c]], ch2, d]
	+ 2 drCO[b,Pair[Momentum[c],h[x]], DiracGamma[Momentum[c]], ch1, d] )/.drCO->ds;

(* g^mu ... g^nu g^rho g_mu, where g^mu is in D, 4, or D-4
	and g^nu and g^rho are in different dimensions is simplfied
	by repeatedly applying anticommuation relations.            *)

drCO[b___ , DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4],    w___,
			DiracGamma[(x2: LorentzIndex | ExplicitLorentzIndex | Momentum)[y2_, dim3_ : 4] ,dim3_ : 4],
			DiracGamma[LorentzIndex[c_, dim1_ : 4], dim1_ : 4], d___] :=
	((
	-ds[b,  DiracGamma[LorentzIndex[c, dim1], dim1], w,
			DiracGamma[LorentzIndex[c, dim1], dim1],
			DiracGamma[x2[y2,dim3],dim3], d]
		+ 2 ds[b, DiracGamma[LorentzIndex[c, dim1], dim1], w,
					Pair [LorentzIndex[c, dim1], x2[y2,dim3]],d]))/;
				(dim1===dim3 || dim3 === dim1-4 || dim1 === dim3-4 || dim3 === 4 || dim1 === 4) &&
				MatchQ[dim1, _Symbol | _Symbol-4 | 4 ] &&
				MatchQ[dim3, _Symbol | _Symbol-4 | 4 ] &&
				!MatchQ[{w, DiracGamma[x2[y2,dim3],dim3]},{DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_, dim3] , dim3]..} |
					{___, DiracGamma[a__], ___, DiracGamma[a__], ___}] && NonCommFreeQ[{w}/.DiracGamma->diga];

(* Slash(p) ... g^nu g^rho Slash(p), where the slashes are in D, 4, or D-4
	and g^nu and g^rho are in different dimensions is simplfied
	by repeatedly applying anticommuation relations.            *)

drCO[b___ , DiracGamma[Momentum[c_, dim1_ : 4], dim1_ : 4], w___,
	DiracGamma[(x2: LorentzIndex | ExplicitLorentzIndex | Momentum)[y2_, dim3_ : 4] ,dim3_ : 4],
	DiracGamma[Momentum[c_, dim1_ : 4], dim1_ : 4], d___] :=
	((-ds[b,  DiracGamma[Momentum[c, dim1], dim1], w,
	DiracGamma[Momentum[c, dim1], dim1],
	DiracGamma[x2[y2,dim3],dim3], d]
	+ 2 ds[b, DiracGamma[Momentum[c, dim1], dim1], w,
			Pair [Momentum[c, dim1], x2[y2,dim3]], d]))/;
		(dim1===dim3 || dim3 === dim1-4 || dim1 === dim3-4 || dim3 === 4 || dim1 === 4) &&
		MatchQ[dim1, _Symbol | _Symbol-4 | 4 ] &&
		MatchQ[dim3, _Symbol | _Symbol-4 | 4 ] &&
		!MatchQ[{w, DiracGamma[x2[y2,dim3],dim3]},{DiracGamma[(LorentzIndex | ExplicitLorentzIndex | Momentum)[_, dim3] , dim3]..} |
			{___, DiracGamma[a__], ___, DiracGamma[a__], ___}] && NonCommFreeQ[{w}/.DiracGamma->diga];

(* ************************************************************** *)
SetAttributes[chiralTrick,Flat];
SetAttributes[drS,Flat];
(* ************************************************************** *)
SetAttributes[dr,Flat];   (* quite important!!! *)
(* ************************************************************** *)

FCPrint[1,"DiracTrick.m loaded."];
End[]
