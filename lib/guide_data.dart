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
    title: 'Marzban All-in-One (VPS အသစ်)',
    summary: 'VPS အသစ်မှာ Marzban တင်နည်း တစ်ဆင့်ချင်း',
    steps: [
      GuideStep(
        title: 'မစခင် ပြင်ဆင်ရန်',
        text: 'VPS အသစ် + IP အဆင်သင့်ထားပြီး root နဲ့ ဝင်ထားပါ။\n\n'
            'Cloudflare မှာ A Record ၂ ခုကို ဒီ VPS IP ကို ညွှန်းပါ။\n'
            '• Panel Domain → DNS only (မဖြစ်မနေ)၊ Port 8000 က Proxy ဖြတ်မရပါ။\n'
            '• Host Domain → DNS only က အလွယ်ဆုံး။ Proxy ဖွင့်ချင်ရင် DNS Token မဖြစ်မနေ လိုပါတယ်။\n\n'
            'ရှိရင် အဆင်သင့်ထားပါ (မရှိလည်း ရ)။\n'
            '• Cloudflare DNS Token (Zone → DNS → Edit)။ Zone တစ်ခုကို Token တစ်ခု၊ အဲဒီ Zone ထဲက VPS တိုင်း ပြန်သုံးလို့ရ။\n'
            '• Backup Bot Token (ညစဉ် Backup ကို Telegram ပို့ချင်ရင်)',
        image: 'g1_0.png',
      ),
      GuideStep(
        title: 'Script ကို Run',
        text: 'Terminal မှာ ဒီတစ်ကြောင်းတည်း Paste လုပ်ပြီး Enter နှိပ်ပါ။ အဝါနဲ့ ပြထားတာက သင်ရိုက်ထည့်ရမယ့်နေရာတွေပါ။',
        image: 'g1_1.png',
        script: 'curl -fsSL "https://sisnaing-marzban.noresult3.workers.dev/marzban.sh" -o /tmp/m.sh && bash /tmp/m.sh',
      ),
      GuideStep(
        title: 'Domain ၂ ခု ထည့်',
        text: 'Panel Domain ထည့်ပြီး Enter၊ Host Domain ထည့်ပြီး Enter။\n\n'
            'ပြီးရင် Script က DNS စစ်ပါမယ်။ IP မကိုက်ရင် သတိပေးပြီး ရပ်သွားနိုင်ပါတယ်။ DNS အရင်ပြင်ထားတာ အကောင်းဆုံးပါ (y နှိပ်ပြီး ဆက်လို့တော့ ရပါတယ်)။',
        image: 'g1_2.png',
      ),
      GuideStep(
        title: 'Cloudflare DNS Token (ရှိရင်ထည့်)',
        text: 'Token ထည့်ရင် Cert ကို DNS နည်းနဲ့ ထုတ်ပြီး Renewal ဘယ်တော့မှ မ Fail ပါဘူး။\n'
            'curl စာကြောင်း တစ်ခုလုံး Paste လုပ်မိလည်း Script က Token အပိုင်းကို အလိုလို ဆွဲထုတ်ပေးပါတယ်။\n'
            'မရှိရင် Enter ပဲ နှိပ်ပါ (HTTP နည်း၊ Host က DNS only ဖြစ်ရမယ်)။\n\n'
            'Token ယူနည်းကို "Cloudflare DNS Token ယူနည်း" လမ်းညွှန်မှာ ကြည့်ပါ။',
        image: 'g1_3.png',
      ),
      GuideStep(
        title: 'အဆင့် ၈ ဆင့် အလိုလို Run မယ်',
        text: 'Packages/Docker → DNS စစ် → Patch + Branded Page → Config → Certificate → Marzban Start → Host သတ်မှတ် → ညစဉ် 03:30 Backup။\n\n'
            'နောက်ဆုံးအဆင့် မတိုင်ခင် Backup Bot Token တစ်ချက်မေးပါမယ်။ Telegram ပို့ချင်ရင် ထည့်၊ မဟုတ်ရင် Enter (Local backup ပဲ ရမယ်)။',
        image: 'g1_4.png',
      ),
      GuideStep(
        title: '"ပြီးပါပြီ" ပေါ်ရင် အောင်မြင်ပြီ',
        text: 'Panel URL နဲ့ Admin Login ပြပါမယ်။ အချက်အလက်တွေကို /root/marzban-admin.txt ထဲလည်း သိမ်းထားပါတယ်။',
        image: 'g1_5.png',
      ),
      GuideStep(
        title: 'App မှာ Server ထည့်',
        text: 'App → Servers → Add မှာ\n• Host = Panel Domain သက်သက် (https:// မပါ)\n• Port 8000\n• HTTPS ဖွင့်\n\n'
            'Save & Auto Run နှိပ်ရင် Login စစ်၊ Inbound ရှာ၊ Front (vip.lovetulip69.com) မှာ Origin Register အလိုလို ဖြစ်ပါမယ်။',
        image: 'g1_6.png',
      ),
      GuideStep(
        title: 'စမ်းရန် — Link ပုံစံ',
        text: 'User တစ်ယောက်ဆောက်ကြည့်ပါ။ Link က ဒီပုံစံနဲ့ ထွက်ရပါမယ်။ ဖုန်းမှာ VPN App ထဲ Import စမ်းပါ၊ Config တက်လာရင် အကုန်ပြီးပါပြီ။',
        image: 'g1_7.png',
        script: 'https://vip.lovetulip69.com/vip/<username>',
      ),
      GuideStep(
        title: 'Fix Mode — Marzban ရှိပြီးသား VPS',
        text: 'အဲဒီ VPS မှာ One-liner ကို ပြန် Run ရင် Reinstall မလုပ်ပါဘူး။ Fix Mode ထဲ အလိုလိုဝင်ပြီး Patch အသစ်ပြန်သွင်း၊ Cert ကို DNS နည်းနဲ့ ပြန်ထုတ်၊ Restart လုပ်ပြီး Dry-run အစမ်းလုပ်ပေးပါမယ်။\n'
            '(သိမ်းထားတဲ့ Token ကို ပြန်သုံးမယ်၊ မရှိရင် မေးမယ်။)\n\n'
            'သုံးရမယ့် အခြေအနေ: Cert Renewal Fail ရင် · Host ကို Proxy ဖွင့်ထားရင် · Short Link က Origin မှာ 404 ဖြစ်ရင်။',
        image: 'g1_f.png',
      ),
      GuideStep(
        title: 'စစ်ရန် Command များ',
        text: 'Inbound က အဆင်သင့် တစ်ခုတည်း: VLESS WS TLS, Port 443, Path /tulipws။\nAdmin Login အချက်အလက်: /root/marzban-admin.txt',
        image: 'g1_cmd.png',
        script: 'marzban status\nmarzban logs',
      ),
    ],
  ),
  Guide(
    title: 'Cloudflare DNS Token ယူနည်း',
    summary: 'Domain တစ်ခုအတွက် Token ယူနည်း (Zone → DNS → Edit)',
    steps: [
      GuideStep(
        title: 'မစခင် — အကောင့် မှန်ဖို့ အရေးကြီး',
        text: 'Token ကို အဲဒီ Domain ရှိတဲ့ Cloudflare အကောင့်ထဲမှာ လုပ်ရမယ်။ Domain တွေ အကောင့်မတူရင် Token လည်း အကောင့်ခွဲပြီး လုပ်ရတယ်။ အကောင့်မှားရင် Installer မှာ Cert ထုတ်တာ Fail မယ်။',
        image: 'g2_warn.png',
      ),
      GuideStep(
        title: '၁။ Cloudflare ဝင် → Domain ကို နှိပ်',
        text: 'dash.cloudflare.com ဝင်ပြီး Domain စာရင်းထဲက သုံးမယ့် Domain ကို နှိပ်ပါ။',
        image: 'g2_1.png',
      ),
      GuideStep(
        title: '၂။ My Profile → API Tokens',
        text: 'ညာဘက်အပေါ်က Profile ပုံ (Avatar) ကို နှိပ် → My Profile → API Tokens tab ကို ဝင်ပါ။\n'
            'အတိုဆုံးလမ်း: Domain ရဲ့ Overview စာမျက်နှာ ညာဘက်က API → Get your API token ကို နှိပ်လည်း ရောက်ပါတယ်။',
        image: 'g2_2.png',
      ),
      GuideStep(
        title: '၃။ Create Token → "Edit zone DNS"',
        text: 'Create Token ကို အရင်နှိပ်ပါ။ Template ထဲက "Edit zone DNS" ကို ရွေးပြီး Use template နှိပ်ပါ။\n'
            'ဒီ Template မှာ Permissions (Zone → DNS → Edit) အသင့်ပါပြီးသားမို့ ကိုယ်ပြင်စရာ မလိုပါဘူး။\n'
            '(Template မသုံးချင်ရင် Custom token နဲ့ Permissions = Zone → DNS → Edit ထည့်ပါ။)',
        image: 'g2_3.png',
      ),
      GuideStep(
        title: '၄။ Zone Resources — Domain ရွေး (အဓိက အဆင့်)',
        text: 'Include → Specific zone → ကိုယ်သုံးမယ့် Domain ကို ရွေးပါ။\n'
            'ဒီအဆင့်က အဓိကပါ။ Token က အဲဒီ Domain တစ်ခုတည်းအတွက်ပဲ ဖြစ်သွားလို့ လုံခြုံပါတယ်။',
        image: 'g2_4.png',
      ),
      GuideStep(
        title: '၅။ Create Token ပြီး Copy ယူ',
        text: 'Continue to summary → Create Token နှိပ်ပါ။\n'
            'Token ပေါ်လာပါမယ်။ တစ်ခါတည်းပဲ ပြတာမို့ Copy ယူထားပါ။ ပျောက်သွားရင် Token အသစ်ပြန်လုပ်ရပါမယ်။',
      ),
      GuideStep(
        title: 'Installer မှာ သုံးပုံ',
        text: '• Script က Token မေးတဲ့အခါ Paste လုပ်ရုံပါပဲ။ curl စာကြောင်း တစ်ခုလုံး Paste မိလည်း ရတယ် (Script က cfut_... အပိုင်းကို အလိုလိုဆွဲထုတ်တယ်၊ အရှည် ၅၃ ဝန်းကျင်)။\n'
            '• Token ကို VPS ထဲ /root/.secrets/certbot/ မှာ သိမ်းထားပြီး Cert Renewal တိုင်း အလိုလိုပြန်သုံးတယ်။ နောက်တစ်ခါ ထပ်ထည့်စရာ မလိုပါဘူး။\n'
            '• Zone တစ်ခုကို Token တစ်ခုပါ။ အဲဒီ Domain ရဲ့ Subdomain သုံးတဲ့ VPS တိုင်း ဒီ Token ကိုပဲ ပြန်သုံးလို့ရတယ်။',
      ),
    ],
  ),
];
