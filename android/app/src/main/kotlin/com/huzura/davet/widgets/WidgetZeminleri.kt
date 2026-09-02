package com.huzura.davet.widgets

import com.huzura.davet.R

/**
 * Widget zeminleri ve saydamlik varyantlari.
 *
 * BU DOSYA URETILMISTIR - elle duzenlemeyin.
 * Kaynak: scratchpad/gen_zemin.py
 *
 * getIdentifier yerine dogrudan R.drawable atifi kullanilir; boylece
 * kaynak kucultucu (shrinkResources) varyantlari silmez.
 */
object WidgetZeminleri {

    /** Yapilandirma ekraninda listelenen zemin anahtarlari (sirali). */
    val ANAHTARLAR = listOf(
        "orange", "light", "dark", "sunset", "green", "purple", "red", "blue", "teal", "pink", "semi_black", "semi_white", "transparent",
    )

    /** Secilebilen saydamlik adimlari (yuzde). */
    val SAYDAMLIK_ADIMLARI = listOf(100, 80, 60, 40, 20)

    /** Uzerine acik renk yazi yerine koyu yazi yakisan zeminler. */
    private val ACIK_ZEMINLER = setOf("light", "sunset", "semi_white")

    /**
     * [anahtar] zemininin [saydamlik] yuzdesindeki cizim kaynagini verir.
     * Bilinmeyen deger gelirse en yakin gecerli adima duser.
     */
    fun zemin(anahtar: String, saydamlik: Int): Int {
        val adim = SAYDAMLIK_ADIMLARI.minByOrNull { kotlin.math.abs(it - saydamlik) } ?: 100
        return when ("$anahtar|$adim") {
            "orange|100" -> R.drawable.widget_bg_orange
            "orange|80" -> R.drawable.widget_bg_orange_a80
            "orange|60" -> R.drawable.widget_bg_orange_a60
            "orange|40" -> R.drawable.widget_bg_orange_a40
            "orange|20" -> R.drawable.widget_bg_orange_a20
            "light|100" -> R.drawable.widget_bg_card_light
            "light|80" -> R.drawable.widget_bg_card_light_a80
            "light|60" -> R.drawable.widget_bg_card_light_a60
            "light|40" -> R.drawable.widget_bg_card_light_a40
            "light|20" -> R.drawable.widget_bg_card_light_a20
            "dark|100" -> R.drawable.widget_bg_card_dark
            "dark|80" -> R.drawable.widget_bg_card_dark_a80
            "dark|60" -> R.drawable.widget_bg_card_dark_a60
            "dark|40" -> R.drawable.widget_bg_card_dark_a40
            "dark|20" -> R.drawable.widget_bg_card_dark_a20
            "sunset|100" -> R.drawable.widget_bg_sunset
            "sunset|80" -> R.drawable.widget_bg_sunset_a80
            "sunset|60" -> R.drawable.widget_bg_sunset_a60
            "sunset|40" -> R.drawable.widget_bg_sunset_a40
            "sunset|20" -> R.drawable.widget_bg_sunset_a20
            "green|100" -> R.drawable.widget_bg_green
            "green|80" -> R.drawable.widget_bg_green_a80
            "green|60" -> R.drawable.widget_bg_green_a60
            "green|40" -> R.drawable.widget_bg_green_a40
            "green|20" -> R.drawable.widget_bg_green_a20
            "purple|100" -> R.drawable.widget_bg_purple
            "purple|80" -> R.drawable.widget_bg_purple_a80
            "purple|60" -> R.drawable.widget_bg_purple_a60
            "purple|40" -> R.drawable.widget_bg_purple_a40
            "purple|20" -> R.drawable.widget_bg_purple_a20
            "red|100" -> R.drawable.widget_bg_red
            "red|80" -> R.drawable.widget_bg_red_a80
            "red|60" -> R.drawable.widget_bg_red_a60
            "red|40" -> R.drawable.widget_bg_red_a40
            "red|20" -> R.drawable.widget_bg_red_a20
            "blue|100" -> R.drawable.widget_bg_blue
            "blue|80" -> R.drawable.widget_bg_blue_a80
            "blue|60" -> R.drawable.widget_bg_blue_a60
            "blue|40" -> R.drawable.widget_bg_blue_a40
            "blue|20" -> R.drawable.widget_bg_blue_a20
            "teal|100" -> R.drawable.widget_bg_teal
            "teal|80" -> R.drawable.widget_bg_teal_a80
            "teal|60" -> R.drawable.widget_bg_teal_a60
            "teal|40" -> R.drawable.widget_bg_teal_a40
            "teal|20" -> R.drawable.widget_bg_teal_a20
            "pink|100" -> R.drawable.widget_bg_pink
            "pink|80" -> R.drawable.widget_bg_pink_a80
            "pink|60" -> R.drawable.widget_bg_pink_a60
            "pink|40" -> R.drawable.widget_bg_pink_a40
            "pink|20" -> R.drawable.widget_bg_pink_a20
            "semi_black|100" -> R.drawable.widget_bg_semi_black
            "semi_black|80" -> R.drawable.widget_bg_semi_black_a80
            "semi_black|60" -> R.drawable.widget_bg_semi_black_a60
            "semi_black|40" -> R.drawable.widget_bg_semi_black_a40
            "semi_black|20" -> R.drawable.widget_bg_semi_black_a20
            "semi_white|100" -> R.drawable.widget_bg_semi_white
            "semi_white|80" -> R.drawable.widget_bg_semi_white_a80
            "semi_white|60" -> R.drawable.widget_bg_semi_white_a60
            "semi_white|40" -> R.drawable.widget_bg_semi_white_a40
            "semi_white|20" -> R.drawable.widget_bg_semi_white_a20
            "transparent|100" -> R.drawable.widget_bg_transparent
            "transparent|80" -> R.drawable.widget_bg_transparent_a80
            "transparent|60" -> R.drawable.widget_bg_transparent_a60
            "transparent|40" -> R.drawable.widget_bg_transparent_a40
            "transparent|20" -> R.drawable.widget_bg_transparent_a20
            else -> R.drawable.widget_bg_card_dark
        }
    }

    /** Zemin acik renkliyse true; yazi rengi buna gore secilir. */
    fun acikZemin(anahtar: String): Boolean = anahtar in ACIK_ZEMINLER
}
