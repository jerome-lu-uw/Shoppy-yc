import SwiftUI
import UIKit

struct SplashScreen: View {
    var body: some View {
        ZStack {
            Theme.ivory
                .ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                ShoppyLogo()
                Text("Shoppy")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("See the fit 👔\nbefore you commit 🛍️")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 28)
                Spacer()
            }
            .padding(.vertical, 64)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ShoppyLogo: View {
    var body: some View {
        Group {
            if let image = Self.appIcon {
                Image(uiImage: image)
                    .resizable()
            } else {
                Image(systemName: "tshirt.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(34)
                    .foregroundStyle(Theme.ink)
                    .background(Theme.studio)
            }
        }
        .scaledToFit()
        .frame(width: 148, height: 148)
        .clipShape(.rect(cornerRadius: 34))
        .shadow(color: Color.black.opacity(0.08), radius: 20, y: 10)
        .accessibilityHidden(true)
    }

    private static let appIcon: UIImage? = {
        guard
            let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String]
        else {
            return nil
        }
        return files.reversed().compactMap(UIImage.init(named:)).first
    }()
}

#Preview {
    SplashScreen()
}
