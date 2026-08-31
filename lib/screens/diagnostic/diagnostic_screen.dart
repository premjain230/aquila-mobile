import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../learning/diagnostic.dart';
import '../../learning/diagnostic_bank.dart';
import '../../learning/evidence.dart';
import '../../theme/aquila_theme.dart';
import '../../widgets/common.dart';

class DiagnosticScreen extends StatefulWidget {
  final String uid;
  const DiagnosticScreen({super.key, required this.uid});
  @override State<DiagnosticScreen> createState()=>_DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen>{
  final _db=FirebaseFirestore.instance;
  String? _diagId;
  List<Map<String,dynamic>> _qs=[];
  int _idx=0;
  int? _sel;
  int? _conf;
  final _answers=<Map<String,dynamic>>[];
  bool _loading=true;

  @override
  void initState(){ super.initState(); _init(); }

  Future<void> _init() async {
    final order = prioritizeConcepts(profile:{'subjects':['Mathematics','Physics']}, masteryMap:{}, scope:{});
    final qs = pickQuestions(conceptOrder:order, count:12);
    _qs=qs;
    final id = await createDiagnostic(db:_db, uid:widget.uid, subject:"Mathematics", scope:{}, masteryMap:{}, profile:{'subjects':['Mathematics']});
    setState((){_diagId=id; _loading=false;});
  }

  Future<void> _submit() async {
    final q=_qs[_idx];
    final selLetter = String.fromCharCode(65+(_sel??0));
    final isCorrect = selLetter==q['answer'];
    await emitLearningEvent(_db, widget.uid, isCorrect?'question_correct':'question_incorrect', conceptId:q['conceptId'], subject:q['subject'], topic:q['topic'], source:'diagnostic', sessionId:_diagId, questionId:q['questionId'], payload:{'correct':isCorrect,'hintCount':0,'mode':'diagnostic'}, confidence:_conf);
    await emitLearningEvent(_db, widget.uid, 'question_answered', conceptId:q['conceptId'], subject:q['subject'], topic:q['topic'], source:'diagnostic', sessionId:_diagId, questionId:q['questionId'], payload:{'correct':isCorrect});
    await emitLearningEvent(_db, widget.uid, 'diagnostic_answered', conceptId:q['conceptId'], subject:q['subject'], topic:q['topic'], source:'diagnostic', sessionId:_diagId, questionId:q['questionId'], payload:{'correct':isCorrect,'hintCount':0});
    _answers.add({'question':q,'isCorrect':isCorrect});
    if(_idx+1 < _qs.length){ setState((){_idx++; _sel=null; _conf=null;}); }
    else { _finish(); }
  }

  Future<void> _finish() async {
    final correct=_answers.where((a)=>a['isCorrect']==true).length;
    await _db.collection('users').doc(widget.uid).collection('diagnostics').doc(_diagId).update({'status':'completed','correct':correct,'totalQ':_qs.length,'accuracy': _qs.isEmpty?0: correct/_qs.length, 'completedAt': FieldValue.serverTimestamp()});
    await emitLearningEvent(_db, widget.uid, 'diagnostic_completed', source:'diagnostic', sessionId:_diagId, payload:{'correct':correct,'totalQ':_qs.length,'accuracy': _qs.isEmpty?0: correct/_qs.length});
    if(!mounted) return;
    showDialog(context:context, builder:(_)=>AlertDialog(title:const Text('Diagnostic complete'), content:Text('$correct/${_qs.length} correct'), actions:[TextButton(onPressed:()=>Navigator.pop(context), child:const Text('OK'))]));
  }

  @override
  Widget build(BuildContext context){
    final ext=AquilaThemeExt.of(context);
    if(_loading) return Scaffold(backgroundColor:ext.bgBase, body:const Center(child:CircularProgressIndicator()));
    if(_qs.isEmpty) return Scaffold(backgroundColor:ext.bgBase, body:Center(child:Text('No questions', style:TextStyle(color:ext.textPrimary))));
    final q=_qs[_idx];
    return Scaffold(
      backgroundColor:ext.bgBase,
      appBar:AppBar(title:Text('${_idx+1}/${_qs.length}', style:ext.monoMicro(11)), backgroundColor:ext.bgBase),
      body: SingleChildScrollView(padding:const EdgeInsets.all(20), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        Text('${q['subject']} • ${q['topic']}', style:ext.monoMicro(11, color:ext.textSecondary)),
        const SizedBox(height:8),
        Text(q['question'].toString(), style:TextStyle(fontFamily:AquilaColors.fontMain, fontSize:16, fontWeight:FontWeight.w600, color:ext.textPrimary)),
        const SizedBox(height:12),
        ...List.generate((q['options'] as List).length, (i){
          final opt=(q['options'] as List)[i].toString();
          return InkWell(onTap:()=>setState(()=>_sel=i), child:Container(margin:const EdgeInsets.symmetric(vertical:6), padding:const EdgeInsets.all(12), decoration:BoxDecoration(color:_sel==i?AquilaColors.accent.withOpacity(0.12):ext.bgCard, borderRadius:BorderRadius.circular(10), border:Border.all(color:_sel==i?AquilaColors.accent:ext.border)), child:Row(children:[Text(String.fromCharCode(65+i), style:TextStyle(fontFamily:AquilaColors.fontMono, color:ext.textSecondary)), const SizedBox(width:8), Expanded(child:Text(opt, style:TextStyle(color:ext.textPrimary)))])));
        }),
        const SizedBox(height:12),
        Text('How confident? (optional)', style:ext.monoMicro(11, color:ext.textSecondary)),
        Row(children:[1,2,3,4,5].map((n)=>Expanded(child: Padding(padding:const EdgeInsets.all(4), child: ChoiceChip(label:Text('$n'), selected:_conf==n, onSelected:(_)=>setState(()=>_conf=n))))).toList()),
        const SizedBox(height:16),
        SizedBox(width:double.infinity, child: FilledButton(onPressed:_sel==null?null:_submit, child:Text(_idx+1==_qs.length?'Finish':'Submit'))),
      ])),
    );
  }
}
