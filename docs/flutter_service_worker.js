'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "ed322cfa4fb042089b5a746d1e34467d",
"version.json": "37079ee17435075e3a53771d4a523a2e",
"splash/img/light-2x.png": "7311f170287c95864f66d8ead905caf2",
"splash/img/dark-4x.png": "0a1c413e7f708d93d930551f9f8dd8d0",
"splash/img/light-3x.png": "c4c4dcfab6e6b6cd2264d4dd095d24cf",
"splash/img/dark-3x.png": "c4c4dcfab6e6b6cd2264d4dd095d24cf",
"splash/img/light-4x.png": "0a1c413e7f708d93d930551f9f8dd8d0",
"splash/img/dark-2x.png": "7311f170287c95864f66d8ead905caf2",
"splash/img/dark-1x.png": "c9a6213c374d2f41f0437358dd99b13d",
"splash/img/light-1x.png": "c9a6213c374d2f41f0437358dd99b13d",
"index.html": "5e0b31dc46464dcd435a26b1a8e97df7",
"/": "5e0b31dc46464dcd435a26b1a8e97df7",
"main.dart.js": "374973b7fceadec1e22f194ea39f204e",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"favicon.png": "658859d9547a3e7cd4893e32341edf3b",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"manifest.json": "fd091ea5bc8f3ccc10f74bd67179fb6a",
"assets/AssetManifest.json": "871b3a2048967b251f2dbb752cb54073",
"assets/NOTICES": "78a6237fa081360ed0bfbdfac781159b",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "0fc70b1db5a2406daee6381a747d9383",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/flutter_map/lib/assets/flutter_map_logo.png": "208d63cc917af9713fc9572bd5c09362",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "8f5da8507c55ed6c73207192c73e4329",
"assets/fonts/MaterialIcons-Regular.otf": "e8f27d07d9174684d93ebd52aca183a3",
"assets/assets/images/counselor_profile_sad.png": "cbf27c80ecd3f1d704fccdab341f38c1",
"assets/assets/images/counselor_profile_reassure.png": "90598bcbefa80ccfe1ee8a126389345a",
"assets/assets/images/counselor_profile_careful.png": "deef0e5fb40f9823981f89dd8bca541d",
"assets/assets/images/counselor_profile_neutral.png": "991b4522ea6504e7e70bf751ce4733be",
"assets/assets/images/counselor_profile_surprised.png": "695ce138f2abc3129a8274d111439c9f",
"assets/assets/images/counselor_profile_warm_smile.png": "a063750f377b049a0b97117716453ccb",
"assets/assets/images/counselor_profile.png": "49c66b28d166567488ca35f8f8c63621",
"assets/assets/images/counselor_profile_sad2.png": "db1b0d5e719cd788ff3203f96702a8f9",
"assets/assets/images/counselor_profile_warm_empathy.png": "9da937557ca2fc4e74957da4c00c90f9",
"assets/assets/images/counselor_profile_thinking.png": "be87b3111b5ecc3c38152de536e10c7f",
"assets/assets/education_data/week1_part4_1.json": "316c96c5f45a9d81ec461762cdfa9a70",
"assets/assets/education_data/week1_part1_2.json": "f022df3110c6af51d7c5d9b9b5aef56f",
"assets/assets/education_data/week1_part5_5.json": "755d1523dc51513828e126896b745b7f",
"assets/assets/education_data/week1_part3_3.json": "025809591acfe1474e6f20aad6b35edd",
"assets/assets/education_data/week1_relaxation_3.json": "cd5f5b934eaaa80bedfbafbd3d57eeea",
"assets/assets/education_data/week1_relaxation_2.json": "1c5ec56922e3e6b7ca42e8cb10e48992",
"assets/assets/education_data/week1_part3_2.json": "55fcd33b378e6ef6b1b9377b25b77314",
"assets/assets/education_data/week1_part6_1.json": "e4538c9d288250d926c16334ee048e3f",
"assets/assets/education_data/week1_part5_4.json": "677fbcc56c89f566dce130733eff9194",
"assets/assets/education_data/week1_part1_3.json": "96cda824712e55bb03b611beed732e90",
"assets/assets/education_data/week1_part1_4.json": "561853d283f31b73fa2487a96caa453c",
"assets/assets/education_data/week1_part5_3.json": "664325e7b8e39e178b638c9175085e4c",
"assets/assets/education_data/week1_part2_1.json": "143eef66f03e97af4ea455a88a5e6ac6",
"assets/assets/education_data/week1_part3_5.json": "f4bcd980379e2f761e3b1cdcd70cf4c1",
"assets/assets/education_data/week1_relaxation_5.json": "dde58d0c7784cb84100a6712d78997e3",
"assets/assets/education_data/week1_part3_9.json": "b66ba178e26514ccdecd5f50c20ebb42",
"assets/assets/education_data/week1_part3_8.json": "6a3e379b320e5eb74200ab54df2e760f",
"assets/assets/education_data/week1_relaxation_4.json": "169376681ca3b5845307d1d4f906ad06",
"assets/assets/education_data/week1_part3_4.json": "2bcd5db4ce2f9f40dac5c7335527bba9",
"assets/assets/education_data/week1_part5_2.json": "695dacebe2f6082f6d3ddf61469e8874",
"assets/assets/education_data/week1_part1_5.json": "dd893612ba4b152070b247c5031d6eec",
"assets/assets/education_data/week1_part4_6.json": "6b9051bd7ae67f066eead6581da7eb29",
"assets/assets/education_data/week1_part3_7.json": "a5134a2fc1fea2500ffeb34a4b311fd1",
"assets/assets/education_data/week1_part6_4.json": "a0919767754827446a121dd28ab7d0ba",
"assets/assets/education_data/week1_part2_3.json": "4bf4f9628ffba2e0a64c1ea6c3ce660b",
"assets/assets/education_data/week1_part5_1.json": "491eb1616a7103697f2182ae332592a1",
"assets/assets/education_data/week1_part1_6.json": "5373e3832284fa962d57682e39434235",
"assets/assets/education_data/week1_part4_5.json": "1e994b97c4f3f54d9b789bcac2fa1dc8",
"assets/assets/education_data/week1_part4_4.json": "e5374f1c116fec4ef014fcc7ee6b2e43",
"assets/assets/education_data/week1_part2_2.json": "ad4e83d9468d402522a3b4e0988d0cf5",
"assets/assets/education_data/week1_part3_6.json": "dc600a1c9e76c622af416c3831526e5e",
"assets/assets/education_data/week1_relaxation_1.json": "eb29df35b37ffc80853c9698a484b706",
"assets/assets/education_data/week1_part3_1.json": "d7f255a1e295e9efbd32b938333d09e7",
"assets/assets/education_data/week1_part6_2.json": "9ca619326e358ee8bc7eae9f0682bd34",
"assets/assets/education_data/week1_part5_7.json": "6c0352dce479984bcdac0597e28b98b4",
"assets/assets/education_data/week1_part4_3.json": "75973f4568b17a225071e9451a05f1fa",
"assets/assets/education_data/week1_part4_2.json": "b12c298fa1213e0255763d0d5141b42f",
"assets/assets/education_data/week1_part1_1.json": "ee42cc5040c855e5da80f668977255fc",
"assets/assets/education_data/week1_part5_6.json": "a2b76e5a47e1b99def8749d9cb3f46b0",
"assets/assets/education_data/week1_part6_3.json": "f6d71e96c9013c9797acb9177235cb7e",
"assets/assets/image/wrong.png": "ee502a53984a9ff692668cf752c4b322",
"assets/assets/image/week2_scenario1.jpg": "91cedfb1c7361109123cfa1e09f77113",
"assets/assets/image/delete2.png": "8e7813da6495471f3af600112a1be5dd",
"assets/assets/image/character9_mid.png": "d4080492665a45c0d1624bfbc660c39f",
"assets/assets/image/imagination.png": "29204c6d826855e43e3512600b802917",
"assets/assets/image/character14_mid.png": "20a052e89e0a78d74ccbeeef01ffcbb0",
"assets/assets/image/correct.png": "0f63361adbbc2dddbfafd13d610a40c1",
"assets/assets/image/men.png": "febc939489d83f9f70863d89a7d5db71",
"assets/assets/image/week2_scenario2.jpg": "d164a772f23c59affaebdec326fa3858",
"assets/assets/image/jellyfish_8th.png": "856891ac123be1961d8b551120465202",
"assets/assets/image/week2_scenario3.jpg": "bd539dc3dd23e35b4867dc8cd538cd8e",
"assets/assets/image/edu_relaxation.png": "b99f8c96fd82e4af3830315e302c2a86",
"assets/assets/image/character19_last.png": "be0a2e7da0e51ea96ae2406a7866f134",
"assets/assets/image/character18_last.png": "297542f901514afde1c9ae978b74e09f",
"assets/assets/image/scenario_1.png": "687b76146954eca627b21ee3c5825a37",
"assets/assets/image/sea_archive_bg.png": "794ad75556f266aa79f17eec2272073c",
"assets/assets/image/week5_scenario3.jpg": "d0a03075209b7b9d2e6bd225a521179f",
"assets/assets/image/week5_scenario2.jpg": "dd55460d53dc752aee2bba6dd6b2bf52",
"assets/assets/image/progressing.png": "217fd1628127fe2b0e5d3d7d9ce520db",
"assets/assets/image/character5_last.png": "05510f6c5a2667c7b165a0bfdbabedea",
"assets/assets/image/character4_last.png": "e55c4605b49a058e9ef6bdb35045b724",
"assets/assets/image/character8_mid.png": "0c2fcbf7536008bc99c7099f4ff4bb62",
"assets/assets/image/scenario_2.png": "de0d569ac7623755208b665b23885406",
"assets/assets/image/jellyfish_smart.png": "985260270cf608e4f4e9faf73385300a",
"assets/assets/image/character13_last.png": "42418491627cb9539e51389d4854b84d",
"assets/assets/image/character12_last.png": "b91bf6eb70c69a6306f7460df9c35978",
"assets/assets/image/week5_scenario1.jpg": "99eebf7cf6fe72c6154996a8f93cefc7",
"assets/assets/image/scenario_3.png": "9804c5a9dd4cf311ea9c04c00bb538d6",
"assets/assets/image/character15_mid.png": "c7e30243f6b68d09547d321e9a2e6685",
"assets/assets/image/character10.png": "4a02db2bd24c28f134f4f39553db03ac",
"assets/assets/image/character5.png": "2905b9a2ce5120e600120718c9ad9f1a",
"assets/assets/image/aquarium_background.png": "a6093541c4ccb7bf629913cf8fa7d0a2",
"assets/assets/image/character20_last.png": "ae9e8602ba28f3336bd03c0daab5720d",
"assets/assets/image/character2_last.png": "a0ddf631981797762c8aaaa25b4c6708",
"assets/assets/image/think_blue.png": "235eb70b5e52f963ae7dbbf10dca4b34",
"assets/assets/image/character4.png": "7a797090f6324e2ca51adf4bdf352002",
"assets/assets/image/character11.png": "c8a3bb31938ff6f3c58f3e442f956e9e",
"assets/assets/image/character13.png": "cd94a037ff4553b441d448c180de98d4",
"assets/assets/image/character6.png": "2207092080101c4bfc89453d93afeec9",
"assets/assets/image/character14_last.png": "f687e896db2982ad5794a017401a50e5",
"assets/assets/image/character15_last.png": "e28587b72a98caa059d168e2da189d46",
"assets/assets/image/character17_mid.png": "a8115c4903ed1a62c51133049a6838ea",
"assets/assets/image/character8_last.png": "041c2c943533dd7cab16e11833f1df9d",
"assets/assets/image/character9_last.png": "364df1ba8ce23e66c84ea71add57dcf4",
"assets/assets/image/character7.png": "81e5e74a42e839e66d4cdb734653e814",
"assets/assets/image/character12.png": "174db569cab29929a7786dd13dba80b9",
"assets/assets/image/daily_diary.png": "7d5abc9af6e875ab97c9c1f72f8db0d4",
"assets/assets/image/character3.png": "0b70f9ba4071ddff749b6cc52d2490cf",
"assets/assets/image/character16.png": "fd659013504a9d1ee85b630aeed7d0d0",
"assets/assets/image/home.png": "9c3df5b03bc4ad96557563bc341a0756",
"assets/assets/image/character16_mid.png": "a394139a6d9745d2df4160158d624ecb",
"assets/assets/image/character17.png": "ceb8a3bbc00dea83b61d4df07d350d0e",
"assets/assets/image/undone.png": "f56b110a4176c6ce3c59ec41429e8b55",
"assets/assets/image/character2.png": "77c359d53f721ec2b5b6e18d56b99290",
"assets/assets/image/character15.png": "9c17bf03e79c371d8a1f38c7d1ae6129",
"assets/assets/image/character2_mid.png": "b651c1e23de087b358a2696dc9b219fc",
"assets/assets/image/character20_mid.png": "b81b57f50c7bc490d8344938a9cd0008",
"assets/assets/image/coral_green.png": "1e0da0861ce00c1161d043a49c10c7fb",
"assets/assets/image/spring.png": "8837905ae18bd70fac7a2d1d3d1fab30",
"assets/assets/image/character14.png": "7d6858ed84ccd4bae9b56984a0e01bcd",
"assets/assets/image/character1.png": "f29bd7cca3efa4e381b3f42ce66c1f72",
"assets/assets/image/character19.png": "1902878a7101266e967fd7399c216a4e",
"assets/assets/image/edu_book1.jpg": "14062868881629baedd7965300581eac",
"assets/assets/image/intro1.png": "e6f9a08a71aeda4d71b2de87b54960d2",
"assets/assets/image/character11_last.png": "704038b7c21610e5ebdc762f01645503",
"assets/assets/image/character7_mid.png": "c78701780deea2a4b23155190f8f6efa",
"assets/assets/image/character18.png": "18276aa3b0352f290ad2e79bb6c2c73d",
"assets/assets/image/Background_wave.png": "833d13f7ec9402fdabb3e948dc71d4b2",
"assets/assets/image/character13_mid.png": "d429ca0d10394976c730540ea3c88d9c",
"assets/assets/image/done.png": "53b9b57c947bb749f557dfc113c9f519",
"assets/assets/image/edu_book2.jpg": "eb7e74ca78f0384f0b6888683411b531",
"assets/assets/image/intro2.png": "efaf3739af18fe02507147b373cbb913",
"assets/assets/image/jellyfish_blue.png": "9a5b66e2408b83a2fb63bd746edfd090",
"assets/assets/image/jellyfish_pink.png": "14039747012f3c64486912405100be57",
"assets/assets/image/intro3.png": "106d689df0cdac960a15d51420f34ead",
"assets/assets/image/edu_book3.jpg": "0c047a875901fc85d249c4a6c17d1186",
"assets/assets/image/logo.png": "658859d9547a3e7cd4893e32341edf3b",
"assets/assets/image/memo.png": "89556f67aa1d39f5ea383c413310b3f3",
"assets/assets/image/character6_last.png": "8bf35aeedc721f252a3cdb5d9131e4da",
"assets/assets/image/character7_last.png": "4a08f9193d623c7d1ad4650bd61102f9",
"assets/assets/image/character12_mid.png": "0000a66fb7edafb5b0bb0c5d6b04c114",
"assets/assets/image/belief.png": "42f93b5b9f9e7491d20ee4ed66255b85",
"assets/assets/image/edu_book6.jpg": "4f66750b06744ebebbcfcb1fa3f42c10",
"assets/assets/image/ending.png": "d5766f7e6a95449dc4ea2de964cfb157",
"assets/assets/image/congrats.png": "9cfeb447bfdbfd5e48594ddf707aa863",
"assets/assets/image/popup2.png": "a47215d0e9ecb32f6aad3cb3aae7c0ec",
"assets/assets/image/consequence.png": "651d0773e3972847a470f2eb5ab5893a",
"assets/assets/image/eduhome.png": "96adfcbd85896c3e46b646a82599335c",
"assets/assets/image/character20.png": "5b69734169a778987ca915afcca1c945",
"assets/assets/image/character9.png": "3a8726c653ed576b08fbf9ac3e23d1a5",
"assets/assets/image/edu_book4.jpg": "dbdfdef6179b8844739d0f85106bc6ec",
"assets/assets/image/finish.png": "9905ca0d0b55404b0501caf3ff417d55",
"assets/assets/image/character6_mid.png": "d95e69ccc17973aa4ebad1c67e9d5a78",
"assets/assets/image/attack.png": "3ff3a55869c9fb5cd7d4d542db712191",
"assets/assets/image/edu_book5.jpg": "c733c907665035826bac7771d2c46f30",
"assets/assets/image/jellyfish.png": "0276a3ac7b057ca9a75a3b2d63caef11",
"assets/assets/image/popup1.png": "6b3342300ddd8d6fd30ed1d3b0285f47",
"assets/assets/image/character8.png": "eabb67b4bfd1cb3741e0d2ad0b663bcc",
"assets/assets/image/delete.png": "cc0e90b0c617456b47a3f08f967d7d2e",
"assets/assets/image/nice.png": "80d573642f436b029572026bcff57b8c",
"assets/assets/image/character10_mid.png": "c414acec93279fa4b8ad470dd89ea7ab",
"assets/assets/image/pink1.png": "9632133a12ea802d7f07372839f1b540",
"assets/assets/image/jellyfish_blue_congrats.png": "1420725e852cf799b6c05f146151ec16",
"assets/assets/image/coral1.png": "52b5ace02e84077984c5bf687288448d",
"assets/assets/image/coral3.png": "6a550693ed13551a852d9359ae1788aa",
"assets/assets/image/character19_mid.png": "6ca9cb94525f640aeba0384c20b9ed71",
"assets/assets/image/pink3.png": "08b48339213f924485724f2367ce7c47",
"assets/assets/image/coral_yellow.png": "6e3e328fdccafb330f5b79df60ebafb9",
"assets/assets/image/pink2.png": "71c7365a0df5201081927aabba482848",
"assets/assets/image/character4_mid.png": "8bbde09e3b6b6d36e2affca652eea1e2",
"assets/assets/image/jellyfish_good_aquarium.png": "4d4e99c22aa3436d39d91506031f6839",
"assets/assets/image/coral2.png": "2999fc469348864f63ade65a6257fc33",
"assets/assets/image/character18_mid.png": "7a7e17e77fc5c39fcdc8aaebb53905c7",
"assets/assets/image/character17_last.png": "fc90eabbc59737ee70f32dac197b8d3e",
"assets/assets/image/character16_last.png": "f0aaf1ef939bf6354ab32bbceb0b55cd",
"assets/assets/image/question_icon.png": "29c404c67b798a07b47523495e06d7e4",
"assets/assets/image/alternative%2520thoughts.png": "3c3fe7adab24b5435084c3b42116ba84",
"assets/assets/image/character5_mid.png": "6cafbcd4d6e5b8f2d6f3d1397dc571fb",
"assets/assets/image/coral5.png": "dfcd27ffcc211cca0866edcd9a5a6cf2",
"assets/assets/image/coral_pink.png": "c82c5e24cbb4fa1548000eae201fb7dd",
"assets/assets/image/battle_scene_bg.png": "9ab64fcce0b62557467ce03dd476ad98",
"assets/assets/image/activating%2520event.png": "7e0ea7eaa71ad39fef8a8a83fce03ba7",
"assets/assets/image/coral4.png": "5f758735b3d2b1c444999e8e9c7b028c",
"assets/assets/relaxation/noti.mp3": "23445ac40595b2db34c8f05e9624e7b7",
"assets/assets/relaxation/week1.mp3": "3593a140ca8b6c2803d9b16e34dac763",
"assets/assets/relaxation/week3.mp3": "33aad07dec903b882ffbfb70b9307bbe",
"assets/assets/relaxation/week2.mp3": "33aad07dec903b882ffbfb70b9307bbe",
"assets/assets/relaxation/week6.mp3": "33aad07dec903b882ffbfb70b9307bbe",
"assets/assets/relaxation/week7.mp3": "33aad07dec903b882ffbfb70b9307bbe",
"assets/assets/relaxation/week5.mp3": "33aad07dec903b882ffbfb70b9307bbe",
"assets/assets/relaxation/week4.mp3": "33aad07dec903b882ffbfb70b9307bbe",
"assets/assets/relaxation/week8.riv": "7c09b9fc17655a0404102f3cb6e1e1d0",
"assets/assets/relaxation/week4.riv": "7c09b9fc17655a0404102f3cb6e1e1d0",
"assets/assets/relaxation/week5.riv": "7c09b9fc17655a0404102f3cb6e1e1d0",
"assets/assets/relaxation/week7.riv": "7c09b9fc17655a0404102f3cb6e1e1d0",
"assets/assets/relaxation/week6.riv": "7c09b9fc17655a0404102f3cb6e1e1d0",
"assets/assets/relaxation/week2.riv": "7c09b9fc17655a0404102f3cb6e1e1d0",
"assets/assets/relaxation/week3.riv": "7c09b9fc17655a0404102f3cb6e1e1d0",
"assets/assets/relaxation/week1.riv": "1a310feaf6d892ed089f42b8932d22ff",
"assets/assets/relaxation/noti.riv": "d5659483ca9d6dac2b6d46f8957ae23d",
"assets/assets/relaxation/week8.mp3": "33aad07dec903b882ffbfb70b9307bbe",
"assets/assets/data/dummy.json": "4ff4ae73f0cc39436ccd5dc3a51d423a",
"assets/assets/data/dummy_rag.json": "b50eec0d2f3a3696a0ad2494d8538dff",
"assets/assets/data/rag_singleton_dataset.jsonl": "bdf2e8b1dbc6495e50573f942037c7a4",
"assets/assets/data/rag_singleton_with_embeddings.jsonl": "5f7cc001583f4748dc9efb689848325d",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
