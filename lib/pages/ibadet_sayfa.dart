import 'package:flutter/material.dart';
import '../services/tema_service.dart';
import '../services/language_service.dart';

class IbadetSayfa extends StatelessWidget {
  const IbadetSayfa({super.key});

  static List<_IbadetContent> _getIcerikler(LanguageService lang) => [
    _IbadetContent(
      title: lang['prayer'] ?? 'Namaz',
      subtitle: lang['prayer_desc'] ?? 'Farzlar, vacipler, sünnetler ve kılınış şekilleri',
      icon: Icons.mosque,
      sections: [
        _IbadetSection(
          title: lang['prayer_summary'] ?? 'Namaz Nedir?',
          items: [
            'Namaz, günde beş vakit kılınan, Müslümanların en önemli ibadetidir.',
            'İslam\'ın beş şartından biridir ve her akıl baliğ Müslümana farzdır.',
            'Namaz, müminin miracı olarak tanımlanmıştır.',
            'Kıyamet günü hesaba çekilecek ilk amel namazdır.',
            'Namaz, kulu Allah\'a yaklaştıran en büyük ibadettir.',
          ],
        ),
        _IbadetSection(
          title: lang['prayer_conditions'] ?? 'Namazın Şartları (12)',
          items: [
            'Dışındaki Şartlar (6):',
            '1. Hadesten taharet (abdest almak, gusül yapmak)',
            '2. Necasetten taharet (beden, elbise ve namaz kılınacak yerin temiz olması)',
            '3. Setr-i avret (örtünmesi gereken yerlerin örtülmesi)',
            '4. İstikbal-i kıble (kıbleye yönelmek)',
            '5. Vakit (namaz vaktinin girmiş olması)',
            '6. Niyet (hangi namazı kılacağını kalben belirlemek)',
            '',
            'İçindeki Şartlar (Rükünler - 6):',
            '1. İftitah tekbiri (başlangıç tekbiri)',
            '2. Kıyam (ayakta durmak)',
            '3. Kıraat (Kur\'an okumak)',
            '4. Rükû (eğilmek)',
            '5. Sücud (secde yapmak)',
            '6. Ka\'de-i ahire (son oturuş)',
          ],
        ),
        _IbadetSection(
          title: lang['prayer_wajib'] ?? 'Namazın Vacipleri (14)',
          items: [
            '1. Namaza "Allahu Ekber" diyerek başlamak',
            '2. Farz namazların ilk iki, nafile namazların her rekâtında Fatiha okumak',
            '3. Fatiha\'yı zamm-ı sureden önce okumak',
            '4. Farz namazların ilk iki rekâtında Fatiha\'dan sonra sure okumak',
            '5. Nafile namazların her rekâtında sure okumak',
            '6. Secdeyi alın üzerine yapmak',
            '7. Üç ve dört rekâtlı namazlarda birinci oturuşu yapmak',
            '8. Her iki oturuşta da tahiyyatı okumak',
            '9. Vitir namazında kunut duası okumak',
            '10. Bayram namazlarında tekbirleri almak',
            '11. Ta\'dil-i erkân (her rüknü sükûnetle yapmak)',
            '12. Namazdan selam ile çıkmak',
            '13. Sehiv secdesini gerektiren durumlarda sehiv secdesi yapmak',
            '14. Tilâvet secdesini gerektiren ayeti namazda okuyunca secde yapmak',
          ],
        ),
        _IbadetSection(
          title: lang['prayer_sunnah'] ?? 'Namazın Sünnetleri',
          items: [
            'Namaza Başlarken:',
            '• Ezan ve kamet okumak (erkekler için)',
            '• Tekbirde elleri kulak hizasına kaldırmak',
            '• Sübhaneke okumak',
            '• Eûzü besmele çekmek',
            '',
            'Kıyamda:',
            '• Sağ eli sol elin üzerine koymak',
            '• Secde yerine bakmak',
            '• Fatiha\'dan sonra "Âmin" demek',
            '',
            'Rükûda:',
            '• "Sübhâne Rabbiye\'l-azîm" demek (3, 5 veya 7 kez)',
            '• Dizleri tutmak',
            '• Sırtı düz tutmak',
            '',
            'Secdede:',
            '• "Sübhâne Rabbiye\'l-a\'lâ" demek (3, 5 veya 7 kez)',
            '• Kolları yere değdirmemek',
            '• Ayak parmaklarını kıbleye yöneltmek',
            '',
            'Oturuşta:',
            '• Tahiyyat, salavat ve duaları okumak',
            '• Sağa ve sola selam vermek',
          ],
        ),
        _IbadetSection(
          title: lang['how_to_pray'] ?? 'Namaz Nasıl Kılınır?',
          items: [
            '1. Abdest al ve kıbleye dön',
            '2. Niyet et (hangi namazı kılacağını belirle)',
            '3. İftitah tekbiri al ("Allahu Ekber" diyerek elleri kaldır)',
            '4. Sübhaneke oku',
            '5. Eûzü besmele çek, Fatiha oku',
            '6. Bir sure veya ayet oku',
            '7. Tekbir alarak rükûya eğil, 3 kez tesbih et',
            '8. "Semiallahu limen hamideh" diyerek doğrul',
            '9. Tekbir alarak secdeye git, 3 kez tesbih et',
            '10. Tekbir alarak otur, tekrar secdeye git',
            '11. İkinci rekâta kalk, aynı şekilde tamamla',
            '12. İkinci rekât sonunda otur, Tahiyyat oku',
            '13. Üç ve dört rekâtlı namazlarda kalkıp tamamla',
            '14. Son oturuşta Tahiyyat, Salavat ve duaları oku',
            '15. Sağa ve sola selam vererek namazı bitir',
          ],
        ),
      ],
    ),
    _IbadetContent(
      title: lang['32_farz'] ?? '32 Farz',
      subtitle: lang['32_farz_desc'] ?? 'İslam\'ın temel farzları detaylı açıklamalarla',
      icon: Icons.format_list_numbered,
      sections: [
        _IbadetSection(
          title: lang['faith_conditions'] ?? 'İmanın Şartları (6)',
          items: [
            '1. Allah\'a iman: Allah\'ın varlığına, birliğine, tüm kemal sıfatlarına ve noksan sıfatlardan münezzeh olduğuna inanmak.',
            '2. Meleklere iman: Allah\'ın nurdan yarattığı, günah işlemeyen, emredileni yapan meleklere inanmak.',
            '3. Kitaplara iman: Allah\'ın peygamberlerine indirdiği ilahi kitaplara (Tevrat, Zebur, İncil, Kur\'an) inanmak.',
            '4. Peygamberlere iman: Hz. Âdem\'den Hz. Muhammed\'e (s.a.v.) kadar tüm peygamberlere inanmak.',
            '5. Ahiret gününe iman: Kıyametin kopacağına, yeniden dirilişe, hesaba, cennet ve cehenneme inanmak.',
            '6. Kadere iman: Hayır ve şerrin Allah\'tan olduğuna, Allah\'ın her şeyi bilip takdir ettiğine inanmak.',
          ],
        ),
        _IbadetSection(
          title: lang['islam_conditions'] ?? 'İslam\'ın Şartları (5)',
          items: [
            '1. Kelime-i Şehadet getirmek: "Eşhedü en lâ ilâhe illallah ve eşhedü enne Muhammeden abduhû ve rasûluh" demek.',
            '2. Namaz kılmak: Günde beş vakit namazı vaktinde eda etmek.',
            '3. Oruç tutmak: Ramazan ayında, şartlarını taşıyan her Müslüman\'ın oruç tutması.',
            '4. Zekât vermek: Nisap miktarı mala sahip olanların, malının kırkta birini fakirlere vermesi.',
            '5. Hacca gitmek: Gücü yeten Müslüman\'ın ömründe bir kez Kâbe\'yi ziyaret etmesi.',
          ],
        ),
        _IbadetSection(
          title: lang['wudu_farz'] ?? 'Abdestin Farzları (4)',
          items: [
            '1. Yüzü yıkamak: Alnın saç bitiminden çene altına, bir kulak yumuşağından diğerine kadar olan bölgeyi yıkamak.',
            '2. Kolları yıkamak: Parmak uçlarından dirseklere kadar (dirsekler dahil) iki kolu yıkamak.',
            '3. Başı mesh etmek: Başın en az dörtte birini ıslak elle mesh etmek.',
            '4. Ayakları yıkamak: Topuklarla birlikte iki ayağı yıkamak.',
          ],
        ),
        _IbadetSection(
          title: lang['ghusl_farz'] ?? 'Guslün Farzları (3)',
          items: [
            '1. Ağza su vermek (mazmaza): Ağzın her tarafına suyun ulaşmasını sağlamak.',
            '2. Burna su çekmek (istinşak): Burnun yumuşak kısmına kadar suyu çekmek.',
            '3. Bütün vücudu yıkamak: Vücutta kuru yer kalmayacak şekilde tüm bedeni yıkamak.',
          ],
        ),
        _IbadetSection(
          title: lang['tayammum_farz'] ?? 'Teyemmümün Farzları (2)',
          items: [
            '1. Niyet etmek: Teyemmümü abdest veya gusül yerine geçirmek niyetiyle yapmak.',
            '2. Yüzü ve kolları mesh etmek: Temiz toprak veya toprak cinsinden bir şeye elleri vurup yüzü mesh etmek, sonra tekrar vurup kolları dirseklere kadar mesh etmek.',
          ],
        ),
        _IbadetSection(
          title: lang['prayer_farz'] ?? 'Namazın Farzları (12)',
          items: [
            'Namazın Dışındaki Farzlar (Şartlar):',
            '1. Hadesten taharet (abdest veya gusül)',
            '2. Necasetten taharet (temizlik)',
            '3. Setr-i avret (örtünme)',
            '4. İstikbal-i kıble (kıbleye yönelme)',
            '5. Vakit (namaz vaktinin girmesi)',
            '6. Niyet (kalben niyet etme)',
            '',
            'Namazın İçindeki Farzlar (Rükünler):',
            '7. İftitah tekbiri (başlangıç tekbiri)',
            '8. Kıyam (ayakta durma)',
            '9. Kıraat (Fatiha ve sure okuma)',
            '10. Rükû (eğilme)',
            '11. Sücud (secde)',
            '12. Ka\'de-i ahire (son oturuş)',
          ],
        ),
      ],
    ),
    _IbadetContent(
      title: lang['54_farz'] ?? '54 Farz',
      subtitle: lang['54_farz_desc'] ?? 'Günlük hayattaki farzlar ve sorumluluklar',
      icon: Icons.checklist,
      sections: [
        _IbadetSection(
          title: lang['faith_conditions'] ?? 'İmanın Şartları (6)',
          items: [
            '1. Allah\'a iman etmek',
            '2. Meleklere iman etmek',
            '3. Kitaplara iman etmek',
            '4. Peygamberlere iman etmek',
            '5. Ahiret gününe iman etmek',
            '6. Kadere, hayır ve şerrin Allah\'tan geldiğine iman etmek',
          ],
        ),
        _IbadetSection(
          title: lang['islam_conditions'] ?? 'İslam\'ın Şartları (5)',
          items: [
            '7. Kelime-i Şehadet getirmek',
            '8. Beş vakit namaz kılmak',
            '9. Ramazan orucunu tutmak',
            '10. Zekât vermek',
            '11. Hacca gitmek (gücü yetene)',
          ],
        ),
        _IbadetSection(
          title: lang['wudu_farz'] ?? 'Abdestin Farzları (4)',
          items: [
            '12. Yüzü bir kez yıkamak',
            '13. İki kolu dirseklerle birlikte yıkamak',
            '14. Başın dörtte birini mesh etmek',
            '15. İki ayağı topuklarla birlikte yıkamak',
          ],
        ),
        _IbadetSection(
          title: lang['ghusl_farz'] ?? 'Guslün Farzları (3)',
          items: [
            '16. Ağza su almak (mazmaza)',
            '17. Burna su çekmek (istinşak)',
            '18. Bütün vücudu yıkamak',
          ],
        ),
        _IbadetSection(
          title: lang['tayammum_farz'] ?? 'Teyemmümün Farzları (2)',
          items: [
            '19. Niyet etmek',
            '20. Elleri temiz toprağa vurup yüzü ve kolları mesh etmek',
          ],
        ),
        _IbadetSection(
          title: lang['prayer_farz'] ?? 'Namazın Farzları (12)',
          items: [
            '21. Hadesten taharet',
            '22. Necasetten taharet',
            '23. Setr-i avret',
            '24. İstikbal-i kıble',
            '25. Vakit',
            '26. Niyet',
            '27. İftitah tekbiri',
            '28. Kıyam',
            '29. Kıraat',
            '30. Rükû',
            '31. Sücud',
            '32. Ka\'de-i ahire',
          ],
        ),
        _IbadetSection(
          title: lang['heart_farz'] ?? 'Kalbin Farzları (7)',
          items: [
            '33. Allah\'a iman ve güvenmek',
            '34. Allah korkusu (takva)',
            '35. Allah sevgisi',
            '36. Allah\'a tevekkül etmek',
            '37. Allah\'tan ümit kesmemek',
            '38. İhlâs (samimi olmak)',
            '39. Şükür (nimete karşı)',
          ],
        ),
        _IbadetSection(
          title: lang['tongue_farz'] ?? 'Dilin Farzları (7)',
          items: [
            '40. Kur\'an okumak (farz miktarı)',
            '41. Doğru konuşmak',
            '42. Allah\'ı zikretmek',
            '43. Gerektiğinde susmak',
            '44. İyiliği emretmek (emr-i bil ma\'ruf)',
            '45. Kötülükten sakındırmak (nehy-i anil münker)',
            '46. İlim öğrenmek ve öğretmek',
          ],
        ),
        _IbadetSection(
          title: lang['body_farz'] ?? 'Bedenin Farzları (8)',
          items: [
            '47. Helal kazanç sağlamak',
            '48. Haramdan kaçınmak',
            '49. Anne-babaya iyilik etmek',
            '50. Akraba ile ilişkiyi sürdürmek',
            '51. Emanete riayet etmek',
            '52. Zulümden kaçınmak',
            '53. Misafire ikram etmek',
            '54. Selama karşılık vermek',
          ],
        ),
      ],
    ),
    _IbadetContent(
      title: lang['friday_prayer'] ?? 'Cuma Namazı',
      subtitle: lang['friday_prayer_desc'] ?? 'Şartları, kılınışı ve fazileti',
      icon: Icons.calendar_today,
      sections: [
        _IbadetSection(
          title: lang['friday_importance'] ?? 'Cuma Namazının Önemi',
          items: [
            'Cuma namazı, hicretin ikinci yılında farz kılınmıştır.',
            'Allah Teâlâ Kur\'an\'da: "Ey iman edenler! Cuma günü namaza çağrıldığında alışverişi bırakıp namaza koşun." (Cuma, 9) buyurmuştur.',
            'Hz. Peygamber (s.a.v.): "Cuma, güneşin doğduğu en hayırlı gündür." buyurmuştur.',
            'Cuma namazını terk eden kişinin kalbi mühürlenir.',
            'Cuma günü yapılan dua kabul olunur.',
          ],
        ),
        _IbadetSection(
          title: lang['friday_conditions'] ?? 'Cuma Namazının Şartları',
          items: [
            'Vücub Şartları (Kimlere Farz):',
            '• Erkek olmak',
            '• Hür olmak',
            '• Mukim olmak (misafir olmamak)',
            '• Sağlıklı olmak',
            '• Özürsüz olmak',
            '',
            'Sıhhat Şartları (Geçerlilik):',
            '• Şehir veya şehir hükmünde bir yerde kılınması',
            '• İzin verilen yerde kılınması',
            '• Öğle vaktinde kılınması',
            '• Hutbe okunması',
            '• Cemaatle kılınması',
          ],
        ),
        _IbadetSection(
          title: lang['friday_how_to_pray'] ?? 'Cuma Namazı Nasıl Kılınır?',
          items: [
            '1. CUMA NAMAZI TOPLAM 16 REKÂTTIR:',
            '',
            '📿 İlk Sünnet (4 Rekât):',
            '   - Öğle namazının ilk sünneti gibi kılınır',
            '   - Her rekâtta Fatiha ve sure okunur',
            '',
            '📿 Farz (2 Rekât):',
            '   - Hutbeden sonra cemaatle kılınır',
            '   - İmam sesli okur',
            '   - Her rekâtta Fatiha ve sure okunur',
            '',
            '📿 Son Sünnet (4 Rekât):',
            '   - Öğle namazının son sünneti gibi kılınır',
            '',
            '📿 Zuhr-i Ahir (4 Rekât):',
            '   - "O günün son öğle namazı" niyetiyle',
            '   - Farz kılınmamış olma ihtimaline karşı',
            '',
            '📿 Vaktin Sünneti (2 Rekât):',
            '   - Son olarak kılınır',
            '',
            '2. HUTBE DİNLEME ADABI:',
            '   - Sessizce dinlemek',
            '   - Konuşmamak',
            '   - Başka şeyle meşgul olmamak',
          ],
        ),
        _IbadetSection(
          title: lang['friday_etiquette'] ?? 'Cuma Günü Adabı',
          items: [
            '• Gusül abdesti almak',
            '• Güzel ve temiz elbise giymek',
            '• Güzel koku sürmek',
            '• Tırnakları kesmek',
            '• Erken gitmek',
            '• Safların arasını sıklaştırmak',
            '• Kehf suresini okumak',
            '• Çokça salavat getirmek',
            '• Dua etmek (kabul saatine denk gelebilir)',
          ],
        ),
      ],
    ),
    _IbadetContent(
      title: lang['funeral_prayer'] ?? 'Cenaze Namazı',
      subtitle: lang['funeral_prayer_desc'] ?? 'Kılınışı, duaları ve hükümleri',
      icon: Icons.brightness_3,
      sections: [
        _IbadetSection(
          title: lang['funeral_importance'] ?? 'Cenaze Namazının Hükmü',
          items: [
            'Cenaze namazı farz-ı kifayedir.',
            'Bir kısım Müslüman kılarsa diğerlerinden sorumluluk kalkar.',
            'Hiç kimse kılmazsa tüm Müslümanlar günahkâr olur.',
            'Cenaze namazı, ölünün bağışlanması için yapılan bir duadır.',
            'Hz. Peygamber (s.a.v.): "Kim bir cenaze namazı kılarsa bir kırat, defnine katılırsa iki kırat sevap alır." buyurmuştur.',
          ],
        ),
        _IbadetSection(
          title: lang['funeral_conditions'] ?? 'Cenaze Namazının Şartları',
          items: [
            '• Meyyitin (ölünün) Müslüman olması',
            '• Cenazenin yıkanmış olması',
            '• Cenazenin kefenlenmiş olması',
            '• Cenazenin önde bulunması',
            '• Namaz kılacak kişinin abdestli olması',
            '• Niyetin edilmesi',
          ],
        ),
        _IbadetSection(
          title: lang['funeral_how_to_pray'] ?? 'Cenaze Namazı Nasıl Kılınır?',
          items: [
            '⚠️ Cenaze namazında rükû ve secde yoktur!',
            '',
            '1. NİYET:',
            '   "Niyet ettim Allah rızası için cenaze namazı kılmaya, meyyite dua etmeye, uydum imama"',
            '',
            '2. BİRİNCİ TEKBİR:',
            '   - "Allahu Ekber" deyip eller bağlanır',
            '   - Sübhaneke okunur (Cenaze sübhanekesi aynıdır)',
            '',
            '3. İKİNCİ TEKBİR:',
            '   - "Allahu Ekber" denir (eller kaldırılmaz)',
            '   - Salavat okunur:',
            '   "Allahümme salli alâ Muhammedin ve alâ âli Muhammed, kemâ salleyte alâ İbrâhîme ve alâ âli İbrâhîm, inneke hamîdün mecîd. Allahümme bârik alâ Muhammedin ve alâ âli Muhammed, kemâ bârekte alâ İbrâhîme ve alâ âli İbrâhîm, inneke hamîdün mecîd."',
            '',
            '4. ÜÇÜNCÜ TEKBİR:',
            '   - "Allahu Ekber" denir',
            '   - Cenaze duası okunur (aşağıda)',
            '',
            '5. DÖRDÜNCÜ TEKBİR:',
            '   - "Allahu Ekber" denir',
            '   - Sağa ve sola selam verilerek namaz bitirilir',
          ],
        ),
        _IbadetSection(
          title: lang['funeral_dua'] ?? 'Cenaze Duası',
          items: [
            'ERKEK İÇİN:',
            '"Allahümma\'ğfir lihayyinâ ve meyyitinâ ve şâhidinâ ve gâibinâ ve sağîrinâ ve kebîrinâ ve zekerinâ ve ünsânâ. Allahümme men ahyeytehu minnâ feahyihî ale\'l-İslâm, ve men teveffeytehu minnâ feteveffehu ale\'l-îmân. Allahümma\'ğfir lehu verhamhu ve âfihi va\'fu anhu ve ekrim nüzulehu ve vessi\' müdḫalehu vağsilhu bi\'l-mâi ve\'s-selci ve\'l-beredi ve nekkıhî mine\'l-hatâyâ kemâ yünekka\'s-sevbü\'l-ebyedu mine\'d-denesi ve ebdilhu dâran hayran min dârihi ve ehlen hayran min ehlihi ve zevcen hayran min zevcihî ve edhilhü\'l-cennete ve eizhü min azâbi\'l-kabri ve azâbin-nâr."',
            '',
            'KADIN İÇİN:',
            '(Aynı dua, "lehu" yerine "lehâ", "ebdilhu" yerine "ebdilhâ" vs. denir)',
            '',
            'ÇOCUK İÇİN:',
            '"Allahümme\'c\'alhü lenâ feratan vec\'alhü lenâ ecran ve zuḫran vec\'alhü lenâ şâfian ve müşeffeâ."',
            '',
            'ANLAMI:',
            '"Allah\'ım! Dirimizi ve ölümüzü, burada bulunanımızı ve bulunmayanımızı, küçüğümüzü ve büyüğümüzü, erkeklerimizi ve kadınlarımızı bağışla. Allah\'ım! Bizden yaşattıklarını İslâm üzere yaşat, öldürdüklerini iman üzere öldür..."',
          ],
        ),
        _IbadetSection(
          title: lang['funeral_steps'] ?? 'Cenaze İşlemleri Sırası',
          items: [
            '1. Ölümün gerçekleşmesi ve tespiti',
            '2. Cenazenin yıkanması (gasil)',
            '3. Kefenlenmesi',
            '4. Cenaze namazının kılınması',
            '5. Kabre taşınması',
            '6. Defnedilmesi',
            '7. Telkin verilmesi',
            '8. Taziye edilmesi',
          ],
        ),
      ],
    ),
    _IbadetContent(
      title: lang['wudu'] ?? 'Abdest',
      subtitle: lang['wudu_desc'] ?? 'Farzları, sünnetleri, adabı ve bozanları',
      icon: Icons.water_drop,
      sections: [
        _IbadetSection(
          title: lang['wudu_farz'] ?? 'Abdestin Farzları (4)',
          items: [
            '1. Yüzü yıkamak: Alnın saç bitim yerinden çene altına, bir kulak yumuşağından diğerine kadar olan bölgeyi en az bir kez yıkamak.',
            '2. Kolları yıkamak: Parmak uçlarından dirseklere kadar (dirsekler dahil) iki kolu en az bir kez yıkamak.',
            '3. Başı mesh etmek: Başın en az dörtte birini ıslak elle bir kez mesh etmek.',
            '4. Ayakları yıkamak: Topuklarla birlikte iki ayağı en az bir kez yıkamak.',
          ],
        ),
        _IbadetSection(
          title: lang['wudu_sunnah'] ?? 'Abdestin Sünnetleri',
          items: [
            '• Besmele çekmek',
            '• Niyet etmek',
            '• Elleri bileklere kadar yıkamak',
            '• Misvak kullanmak',
            '• Mazmaza (ağıza su almak)',
            '• İstinşak (buruna su çekmek)',
            '• Sakalı hilallemek',
            '• Parmak aralarını hilallemek',
            '• Başın tamamını mesh etmek',
            '• Kulakları mesh etmek',
            '• Her uzvu üçer kez yıkamak',
            '• Uzuvları sırasıyla yıkamak (tertip)',
            '• Ara vermeden yıkamak (muvalat)',
            '• Sağdan başlamak',
            '• Uzuvları ovmak',
          ],
        ),
        _IbadetSection(
          title: lang['wudu_breakers'] ?? 'Abdesti Bozan Durumlar',
          items: [
            '• Ön veya arkadan herhangi bir şeyin çıkması',
            '• Yellenmek',
            '• Uyku (tam gevşeme ile)',
            '• Bayılma, delirme, sarhoşluk',
            '• Namazda kahkaha ile gülmek',
            '• Ağız dolusu kusmak',
            '• Yaradan kan, irin vb. akması',
            '',
            'Abdesti Bozmayan Durumlar:',
            '• Karşı cinse dokunmak (Hanefi\'de)',
            '• Çiğ et yemek',
            '• Küçük yaradan az kan gelmesi',
            '• Saç, sakal kesmek veya tıraş olmak',
          ],
        ),
        _IbadetSection(
          title: lang['wudu_how'] ?? 'Abdest Nasıl Alınır?',
          items: [
            '1. Niyet et ve besmele çek',
            '2. Elleri bileklere kadar 3 kez yıka',
            '3. Ağıza 3 kez su al (mazmaza)',
            '4. Buruna 3 kez su çek (istinşak)',
            '5. Yüzü 3 kez yıka',
            '6. Sağ kolu dirsekle birlikte 3 kez yıka',
            '7. Sol kolu dirsekle birlikte 3 kez yıka',
            '8. Islak elle başı mesh et',
            '9. Kulakları mesh et',
            '10. Boynu mesh et',
            '11. Sağ ayağı topukla birlikte 3 kez yıka',
            '12. Sol ayağı topukla birlikte 3 kez yıka',
            '13. Kelime-i şehadet getir ve dua et',
          ],
        ),
      ],
    ),
    _IbadetContent(
      title: lang['tayammum'] ?? 'Teyemmüm',
      subtitle: lang['tayammum_desc'] ?? 'Su bulunmadığında veya kullanılamadığında',
      icon: Icons.landscape,
      sections: [
        _IbadetSection(
          title: lang['tayammum_when'] ?? 'Teyemmüm Ne Zaman Yapılır?',
          items: [
            '• Su bulunmadığında',
            '• Su olup kullanmaya gücü yetmediğinde',
            '• Su kullanmanın hastalığı artıracağı veya iyileşmeyi geciktireceği durumlarda',
            '• Suyun sadece içmek için yeteceği durumlarda',
            '• Suyu kullanırsa malına veya canına zarar geleceği durumlarda',
            '• Vakit çıkacak ve su aramaya zaman yetmeyeceği durumlarda',
          ],
        ),
        _IbadetSection(
          title: lang['tayammum_farz'] ?? 'Teyemmümün Farzları (2)',
          items: [
            '1. Niyet etmek: Abdest veya gusül yerine geçirmek üzere niyet etmek şarttır.',
            '2. Yüzü ve kolları mesh etmek: Temiz toprak veya toprak cinsinden bir şeye iki eli vurup yüzü mesh etmek, sonra tekrar vurup kolları dirseklere kadar mesh etmek.',
          ],
        ),
        _IbadetSection(
          title: lang['tayammum_how'] ?? 'Teyemmüm Nasıl Yapılır?',
          items: [
            '1. Niyet et (abdest veya gusül için)',
            '2. Besmele çek',
            '3. Ellerini temiz toprağa veya toprak cinsinden bir şeye vur',
            '4. Elleri birbirine sil (fazla tozu gider)',
            '5. Yüzünü mesh et',
            '6. Tekrar elleri toprağa vur',
            '7. Sağ kolunu sol elinle mesh et (dirsekle birlikte)',
            '8. Sol kolunu sağ elinle mesh et (dirsekle birlikte)',
            '9. Parmak aralarını mesh et',
          ],
        ),
        _IbadetSection(
          title: lang['tayammum_breakers'] ?? 'Teyemmümü Bozan Durumlar',
          items: [
            '• Abdesti bozan her şey teyemmümü de bozar',
            '• Su bulunması',
            '• Suyu kullanmaya engel olan özrün kalkması',
            '• Namaz kılarken su görülmesi (namaz bozulur)',
          ],
        ),
      ],
    ),
    _IbadetContent(
      title: lang['prayer_duas'] ?? 'Namazda Okunan Sure ve Dualar',
      subtitle: lang['prayer_duas_desc'] ?? 'Namazda okunan sureler, dualar ve anlamları',
      icon: Icons.menu_book,
      sections: [
        _IbadetSection(
          title: 'Sübhaneke',
          items: [
            'سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ وَتَبَارَكَ اسْمُكَ وَتَعَالَى جَدُّكَ وَلَا إِلَهَ غَيْرُكَ',
            '',
            'Okunuşu:',
            'Sübhânekellahümme ve bihamdike ve tebârekesmüke ve teâlâ ceddüke ve lâ ilâhe gayrük.',
            '',
            'Anlamı:',
            'Allah\'ım! Seni her türlü noksanlıktan tenzih ederim. Sana hamd ederim. Senin adın mübarektir. Senin şanın yücedir. Senden başka ilah yoktur.',
          ],
        ),
        _IbadetSection(
          title: 'Fatiha Suresi',
          items: [
            'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
            'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
            'الرَّحْمَنِ الرَّحِيمِ',
            'مَالِكِ يَوْمِ الدِّينِ',
            'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
            'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
            'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ',
            '',
            'Okunuşu:',
            'Bismillâhirrahmânirrahîm. Elhamdü lillâhi rabbil\'âlemîn. Errahmânirrahîm. Mâliki yevmiddîn. İyyâke na\'büdü ve iyyâke neste\'în. İhdinas-sirâtal-müstakîm. Sirâtallezîne en\'amte aleyhim gayril-mağdûbi aleyhim veleddâllîn.',
            '',
            'Anlamı:',
            'Rahman ve Rahim olan Allah\'ın adıyla. Hamd, âlemlerin Rabbi Allah\'a mahsustur. O, Rahman ve Rahim\'dir. Din gününün sahibidir. Ancak sana ibadet eder ve ancak senden yardım dileriz. Bizi doğru yola ilet. Nimet verdiklerinin yoluna; gazaba uğrayanların ve sapkınların yoluna değil.',
          ],
        ),
        _IbadetSection(
          title: 'İhlas Suresi',
          items: [
            'قُلْ هُوَ اللَّهُ أَحَدٌ',
            'اللَّهُ الصَّمَدُ',
            'لَمْ يَلِدْ وَلَمْ يُولَدْ',
            'وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ',
            '',
            'Okunuşu:',
            'Kul hüvallâhü ehad. Allâhüssamed. Lem yelid ve lem yûled. Ve lem yekün lehû küfüven ehad.',
            '',
            'Anlamı:',
            'De ki: O Allah birdir. Allah Samed\'dir (her şey O\'na muhtaç, O hiçbir şeye muhtaç değildir). Doğurmamış ve doğmamıştır. Hiçbir şey O\'nun dengi değildir.',
          ],
        ),
        _IbadetSection(
          title: 'Felak Suresi',
          items: [
            'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ',
            'مِنْ شَرِّ مَا خَلَقَ',
            'وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ',
            'وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ',
            'وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ',
            '',
            'Okunuşu:',
            'Kul e\'ûzü bi-rabbil-felak. Min şerri mâ halak. Ve min şerri gâsikın izâ vekab. Ve min şerrin-neffâsâti fil-\'ukad. Ve min şerri hâsidin izâ hased.',
            '',
            'Anlamı:',
            'De ki: Yarattığı şeylerin şerrinden, karanlığı çöktüğü zaman gecenin şerrinden, düğümlere üfleyenlerin şerrinden ve haset ettiği zaman hasetçinin şerrinden sabahın Rabbine sığınırım.',
          ],
        ),
        _IbadetSection(
          title: 'Nas Suresi',
          items: [
            'قُلْ أَعُوذُ بِرَبِّ النَّاسِ',
            'مَلِكِ النَّاسِ',
            'إِلَهِ النَّاسِ',
            'مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ',
            'الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ',
            'مِنَ الْجِنَّةِ وَالنَّاسِ',
            '',
            'Okunuşu:',
            'Kul e\'ûzü bi-rabbin-nâs. Melikin-nâs. İlâhin-nâs. Min şerril-vesvâsil-khannâs. Ellezî yüvesvisü fî sudûrin-nâs. Minel-cinneti ven-nâs.',
            '',
            'Anlamı:',
            'De ki: İnsanların Rabbine sığınırım. İnsanların Melikine, İnsanların İlahına. Sinsi vesvesecinin şerrinden. O ki insanların göğüslerine vesvese verir. Gerek cinlerden, gerek insanlardan.',
          ],
        ),
        _IbadetSection(
          title: 'Kevser Suresi',
          items: [
            'إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ',
            'فَصَلِّ لِرَبِّكَ وَانْحَرْ',
            'إِنَّ شَانِئَكَ هُوَ الْأَبْتَرُ',
            '',
            'Okunuşu:',
            'İnnâ a\'taynâkel-kevser. Fesalli li-rabbike venhar. İnne şâni\'eke hüvel-ebter.',
            '',
            'Anlamı:',
            'Muhakkak ki biz sana Kevser\'i verdik. Öyleyse Rabbin için namaz kıl ve kurban kes. Doğrusu asıl sonu kesik olan, sana buğzeden kimsedir.',
          ],
        ),
        _IbadetSection(
          title: 'Fil Suresi',
          items: [
            'أَلَمْ تَرَ كَيْفَ فَعَلَ رَبُّكَ بِأَصْحَابِ الْفِيلِ',
            'أَلَمْ يَجْعَلْ كَيْدَهُمْ فِي تَضْلِيلٍ',
            'وَأَرْسَلَ عَلَيْهِمْ طَيْرًا أَبَابِيلَ',
            'تَرْمِيهِمْ بِحِجَارَةٍ مِنْ سِجِّيلٍ',
            'فَجَعَلَهُمْ كَعَصْفٍ مَأْكُولٍ',
            '',
            'Okunuşu:',
            'Elem tera keyfe fe\'ale rabbüke bi-ashâbil-fîl. Elem yec\'al keydehüm fî tadlîl. Ve ersele aleyhim tayran ebâbîl. Termîhim bi-hicâratin min siccîl. Fece\'alehüm ke\'asfin me\'kûl.',
            '',
            'Anlamı:',
            'Rabbinin fil sahiplerine ne yaptığını görmedin mi? Onların tuzaklarını boşa çıkarmadı mı? Üzerlerine sürü sürü kuşlar gönderdi. Onlara pişmiş çamurdan taşlar atıyorlardı. Sonunda onları yenilmiş ekin yaprağı gibi yaptı.',
          ],
        ),
        _IbadetSection(
          title: 'Ettehiyyatü',
          items: [
            'التَّحِيَّاتُ لِلّهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ، اَلسَّلاَمُ عَلَيْكَ اَيُّهَا النَّبِيُّ وَرَحْمَةُ اللّهِ وَبَرَكَاتُهُ، اَلسَّلاَمُ عَلَيْنَا وَعَلَى عِبَادِ اللّهِ الصَّالِحِينَ، اَشْهَدُ اَنْ لاَ اِلَهَ اِلاَّ اللّهُ وَاَشْهَدُ اَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ',
            '',
            'Okunuşu:',
            'Ettehiyyâtü lillâhi vessalavâtü vettayyibât. Esselâmü aleyke eyyühen-nebiyyü ve rahmetullâhi ve berakâtüh. Esselâmü aleynâ ve alâ ibâdillâhis-sâlihîn. Eşhedü en lâ ilâhe illallâh ve eşhedü enne Muhammeden abdühû ve rasûlüh.',
            '',
            'Anlamı:',
            'Bütün tahiyyeler, salavâtlar, tayyibeler Allah içindir. Ey Peygamber! Allah\'ın selamı, rahmeti ve bereketleri senin üzerine olsun. Selam bizim ve Allah\'ın salih kulları üzerine olsun. Şehadet ederim ki Allah\'tan başka ilah yoktur ve şehadet ederim ki Muhammed O\'nun kulu ve rasulüdür.',
          ],
        ),
        _IbadetSection(
          title: 'Allahümme Salli ve Barik',
          items: [
            'اَللّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا صَلَّيْتَ عَلَى اِبْرَاهِيمَ وَعَلَى آلِ اِبْرَاهِيمَ اِنَّكَ حَمِيدٌ مَجِيدٌ',
            '',
            'Okunuşu:',
            'Allahümme salli alâ Muhammedin ve alâ âli Muhammed. Kemâ salleyte alâ İbrâhîme ve alâ âli İbrâhîm. İnneke hamîdün mecîd.',
            '',
            'اَللّهُمَّ بَارِكْ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا بَارَكْتَ عَلَى اِبْرَاهِيمَ وَعَلَى آلِ اِبْرَاهِيمَ اِنَّكَ حَمِيدٌ مَجِيدٌ',
            '',
            'Okunuşu:',
            'Allahümme bârik alâ Muhammedin ve alâ âli Muhammed. Kemâ bârekte alâ İbrâhîme ve alâ âli İbrâhîm. İnneke hamîdün mecîd.',
            '',
            'Anlamı:',
            'Allah\'ım! Muhammed\'e ve Muhammed\'in ailesine rahmet et, İbrahim\'e ve İbrahim\'in ailesine rahmet ettiğin gibi. Şüphesiz sen övülmeye layık ve yücesin. Allah\'ım! Muhammed\'e ve Muhammed\'in ailesine bereket ver, İbrahim\'e ve İbrahim\'in ailesine bereket verdiğin gibi. Şüphesiz sen övülmeye layık ve yücesin.',
          ],
        ),
        _IbadetSection(
          title: 'Rabbena Duaları',
          items: [
            'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
            '',
            'Okunuşu:',
            'Rabbenâ âtinâ fid-dünyâ haseneten ve fil-âhireti haseneten ve kınâ azâben-nâr.',
            '',
            'Anlamı:',
            'Rabbimiz! Bize dünyada iyilik ver, ahirette de iyilik ver ve bizi ateş azabından koru.',
            '',
            '---',
            '',
            'رَبَّنَا لَا تُؤَاخِذْنَا إِنْ نَسِينَا أَوْ أَخْطَأْنَا',
            '',
            'Okunuşu:',
            'Rabbenâ lâ tüâhiznâ in nesînâ ev ahta\'nâ.',
            '',
            'Anlamı:',
            'Rabbimiz! Unutursak veya hata yaparsak bizi sorumlu tutma.',
          ],
        ),
        _IbadetSection(
          title: 'Rükû ve Secde Tesbihleri',
          items: [
            'RÜKÛ TESBİHİ:',
            'سُبْحَانَ رَبِّيَ الْعَظِيمِ',
            'Okunuşu: Sübhâne rabbiye\'l-azîm.',
            'Anlamı: Yüce Rabbimi tesbih ederim (noksanlıklardan tenzih ederim).',
            '(En az 3 kez okunur)',
            '',
            'RÜKÛDAN DOĞRULURKEN:',
            'سَمِعَ اللَّهُ لِمَنْ حَمِدَهُ',
            'Okunuşu: Semi\'allâhu limen hamideh.',
            'Anlamı: Allah kendisine hamd edeni işitir.',
            '',
            'DOĞRULDUKTAN SONRA:',
            'رَبَّنَا لَكَ الْحَمْدُ',
            'Okunuşu: Rabbenâ lekel hamd.',
            'Anlamı: Rabbimiz! Hamd sanadır.',
            '',
            'SECDE TESBİHİ:',
            'سُبْحَانَ رَبِّيَ الْأَعْلَى',
            'Okunuşu: Sübhâne rabbiye\'l-a\'lâ.',
            'Anlamı: En yüce Rabbimi tesbih ederim.',
            '(En az 3 kez okunur)',
          ],
        ),
        _IbadetSection(
          title: 'Kunut Duaları (Vitir)',
          items: [
            'اَللّهُمَّ اِنَّا نَسْتَعِينُكَ وَنَسْتَغْفِرُكَ وَنَسْتَهْدِيكَ وَنُؤْمِنُ بِكَ وَنَتُوبُ اِلَيْكَ وَنَتَوَكَّلُ عَلَيْكَ وَنُثْنِي عَلَيْكَ الْخَيْرَ كُلَّهُ نَشْكُرُكَ وَلاَ نَكْفُرُكَ وَنَخْلَعُ وَنَتْرُكُ مَنْ يَفْجُرُكَ',
            '',
            'Okunuşu:',
            'Allahümme innâ neste\'înüke ve nestagfiruke ve nestehdîke ve nü\'minü bike ve netûbü ileyke ve netevekkelu aleyke ve nüsnî aleykel-hayra küllehû neşküruke ve lâ nekfüruke ve nahleu ve netrukü men yefcüruk.',
            '',
            '---',
            '',
            'اَللّهُمَّ اِيَّاكَ نَعْبُدُ وَلَكَ نُصَلِّي وَنَسْجُدُ وَاِلَيْكَ نَسْعَى وَنَحْفِدُ وَنَرْجُو رَحْمَتَكَ وَنَخْشَى عَذَابَكَ اِنَّ عَذَابَكَ بِالْكُفَّارِ مُلْحِقٌ',
            '',
            'Okunuşu:',
            'Allahümme iyyâke na\'büdü ve leke nusallî ve nescüdü ve ileyke nes\'â ve nahfidü ve nercû rahmeteke ve nahşâ azâbeke inne azâbeke bil-küffâri mülhık.',
            '',
            'Anlamı:',
            'Allah\'ım! Senden yardım dileriz, bağışlamanı isteriz, hidayetini isteriz. Sana iman eder, sana tövbe eder, sana tevekkül ederiz. Bütün hayırla seni överiz. Sana şükreder ve nankörlük etmeyiz. Sana karşı günah işleyeni reddeder ve terk ederiz. Allah\'ım! Yalnız sana ibadet ederiz. Senin için namaz kılar ve secde ederiz. Sana yöneliriz. Rahmetini umarız. Azabından korkarız. Şüphesiz senin azabın kâfirlere ulaşacaktır.',
          ],
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final temaService = TemaService();
    final renkler = temaService.renkler;
    final languageService = LanguageService();
    final icerikler = _getIcerikler(languageService);

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(
          languageService['worship'] ?? 'İbadet',
          style: TextStyle(color: renkler.yaziPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: icerikler.length,
        itemBuilder: (context, index) {
          final content = icerikler[index];
          return _IbadetCard(content: content, renkler: renkler);
        },
      ),
    );
  }
}

class _IbadetCard extends StatelessWidget {
  final _IbadetContent content;
  final TemaRenkleri renkler;

  const _IbadetCard({
    required this.content,
    required this.renkler,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: renkler.kartArkaPlan,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: renkler.vurgu.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(content.icon, color: renkler.vurgu),
        ),
        title: Text(
          content.title,
          style: TextStyle(
            color: renkler.yaziPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          content.subtitle,
          style: TextStyle(color: renkler.yaziSecondary, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: renkler.yaziSecondary),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _IbadetDetaySayfa(content: content),
            ),
          );
        },
      ),
    );
  }
}

class _IbadetDetaySayfa extends StatelessWidget {
  final _IbadetContent content;

  const _IbadetDetaySayfa({required this.content});

  @override
  Widget build(BuildContext context) {
    final temaService = TemaService();
    final renkler = temaService.renkler;

    return Scaffold(
      backgroundColor: renkler.arkaPlan,
      appBar: AppBar(
        title: Text(content.title, style: TextStyle(color: renkler.yaziPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: renkler.yaziPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  renkler.vurgu.withOpacity(0.2),
                  renkler.vurgu.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(content.icon, color: renkler.vurgu, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    content.subtitle,
                    style: TextStyle(color: renkler.yaziSecondary, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...content.sections.map(
            (section) => _IbadetSectionCard(
              section: section,
              renkler: renkler,
            ),
          ),
        ],
      ),
    );
  }
}

class _IbadetSectionCard extends StatelessWidget {
  final _IbadetSection section;
  final TemaRenkleri renkler;

  const _IbadetSectionCard({
    required this.section,
    required this.renkler,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renkler.kartArkaPlan,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: renkler.ayirac),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: TextStyle(
              color: renkler.vurgu,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...section.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: item.isEmpty
                  ? const SizedBox(height: 8)
                  : item.startsWith('---')
                      ? Divider(color: renkler.ayirac, height: 24)
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!item.startsWith(' ') && 
                                !item.startsWith('•') &&
                                !RegExp(r'^\d+\.').hasMatch(item) &&
                                !item.contains(':') &&
                                item.length < 50)
                              const SizedBox()
                            else if (item.startsWith('•') || item.startsWith(' '))
                              const SizedBox()
                            else if (!RegExp(r'^\d+\.').hasMatch(item))
                              Text('• ', style: TextStyle(color: renkler.vurgu)),
                            Expanded(
                              child: SelectableText(
                                item,
                                style: TextStyle(
                                  color: item.contains(':') && !item.contains('Okunuşu:') && !item.contains('Anlamı:')
                                      ? renkler.yaziPrimary.withOpacity(0.9)
                                      : renkler.yaziPrimary,
                                  fontWeight: (item.contains(':') && item.length < 40) || 
                                              item.startsWith('Okunuşu:') || 
                                              item.startsWith('Anlamı:')
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  height: 1.5,
                                  fontSize: item.contains('سُبْ') || item.contains('الْ') || item.contains('قُلْ')
                                      ? 18
                                      : 14,
                                ),
                                textDirection: item.contains('سُبْ') || item.contains('الْ') || item.contains('قُلْ')
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IbadetContent {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_IbadetSection> sections;

  const _IbadetContent({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.sections,
  });
}

class _IbadetSection {
  final String title;
  final List<String> items;

  const _IbadetSection({
    required this.title,
    required this.items,
  });
}
