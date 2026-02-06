import WidgetKit
import SwiftUI

@main
struct HuzurVaktiWidgetBundle: WidgetBundle {
    var body: some Widget {
        KlasikTuruncuWidget()
        MiniSunsetWidget()
        GlassmorphismWidget()
        NeonGlowWidget()
        TimelineWidget()
        CosmicWidget()
        ZenWidget()
        OrigamiWidget()
    }
}

struct KlasikTuruncuWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KlasikTuruncuWidget", provider: WidgetProvider()) { entry in
            WidgetRootView(entry: entry, style: .klasikTuruncu)
        }
        .configurationDisplayName("Klasik Turuncu")
        .description("Vakit bilgilerini klasik turuncu temayla gosterir.")
        .supportedFamilies(WidgetFamilies.all)
    }
}

struct MiniSunsetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MiniSunsetWidget", provider: WidgetProvider()) { entry in
            WidgetRootView(entry: entry, style: .miniSunset)
        }
        .configurationDisplayName("Mini Sunset")
        .description("Gunun vaktini sade bir gorunumle gosterir.")
        .supportedFamilies(WidgetFamilies.all)
    }
}

struct GlassmorphismWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GlassmorphismWidget", provider: WidgetProvider()) { entry in
            WidgetRootView(entry: entry, style: .glassmorphism)
        }
        .configurationDisplayName("Glassmorphism")
        .description("Cam efektli yumusak bir gorunum.")
        .supportedFamilies(WidgetFamilies.all)
    }
}

struct NeonGlowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NeonGlowWidget", provider: WidgetProvider()) { entry in
            WidgetRootView(entry: entry, style: .neonGlow)
        }
        .configurationDisplayName("Neon Glow")
        .description("Neon vurgu rengi ile canli bir tema.")
        .supportedFamilies(WidgetFamilies.all)
    }
}

struct TimelineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TimelineWidget", provider: WidgetProvider()) { entry in
            WidgetRootView(entry: entry, style: .timeline)
        }
        .configurationDisplayName("Timeline")
        .description("Vakitleri listeleyen zaman cizgisi temasi.")
        .supportedFamilies(WidgetFamilies.all)
    }
}

struct CosmicWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CosmicWidget", provider: WidgetProvider()) { entry in
            WidgetRootView(entry: entry, style: .cosmic)
        }
        .configurationDisplayName("Cosmic")
        .description("Gece temali kozmik bir gorunum.")
        .supportedFamilies(WidgetFamilies.all)
    }
}

struct ZenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZenWidget", provider: WidgetProvider()) { entry in
            WidgetRootView(entry: entry, style: .zen)
        }
        .configurationDisplayName("Zen")
        .description("Sakin ve minimal bir tema.")
        .supportedFamilies(WidgetFamilies.all)
    }
}

struct OrigamiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OrigamiWidget", provider: WidgetProvider()) { entry in
            WidgetRootView(entry: entry, style: .origami)
        }
        .configurationDisplayName("Origami")
        .description("Katmanli ve geometrik bir gorunum.")
        .supportedFamilies(WidgetFamilies.all)
    }
}
