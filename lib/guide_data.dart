/// Step-by-step guides. To add content: put images in assets/guide/ and add steps here.
class GuideStep {
  final String title;
  final String text;
  final String? image;  // file name inside assets/guide/, e.g. 'step1.png'
  final String? script; // shown in a box with a Copy button
  const GuideStep({required this.title, required this.text, this.image, this.script});
}

class Guide {
  final String title;
  final String summary;
  final List<GuideStep> steps;
  const Guide({required this.title, required this.summary, required this.steps});
}

const guides = <Guide>[
  Guide(
    title: 'နမူနာ လမ်းညွှန်',
    summary: 'ဒါက နမူနာပါ၊ စာနဲ့ ပုံ ရောက်လာရင် အစားထိုးပါမယ်',
    steps: [
      GuideStep(title: 'အဆင့် ၁', text: 'ပထမအဆင့်ရဲ့ ရှင်းလင်းချက် ဒီမှာ ပေါ်ပါမယ်။'),
      GuideStep(title: 'အဆင့် ၂', text: 'Script ပါရင် အောက်က box မှာ ပြပြီး Copy နှိပ်လို့ရပါတယ်။', script: 'echo hello'),
    ],
  ),
];
