// The look shared by DO IT's screens: green, black and white, soft glowing
// cards, and big friendly buttons.
import SwiftUI

let doitGreen = Color(red: 0, green: 0.82, blue: 0.42)
let doitGreenLight = Color(red: 0.45, green: 1, blue: 0.62)
let doitGreenDark = Color(red: 0, green: 0.45, blue: 0.24)
let doitRed = Color(red: 1, green: 0.27, blue: 0.27)

/// Black with a soft green glow at the top.
struct GlowBackground: View {
    var color: Color = doitGreen
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [color.opacity(0.32), .clear],
                           center: UnitPoint(x: 0.5, y: 0), startRadius: 0, endRadius: 460)
            RadialGradient(colors: [color.opacity(0.10), .clear],
                           center: UnitPoint(x: 1, y: 0.7), startRadius: 0, endRadius: 360)
        }
        .ignoresSafeArea()
    }
}

/// A rounded box that holds one part of the screen.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.04)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// The top of a card: a small icon tile and the card's name.
struct CardHeader<Trailing: View>: View {
    let icon: String
    let title: String
    var color: Color = doitGreen
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 34, height: 34)
                .background(LinearGradient(colors: [color == doitGreen ? doitGreenLight : color, color],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title).font(.subheadline.weight(.heavy)).kerning(0.8).foregroundColor(.white)
            Spacer(minLength: 0)
            trailing
        }
    }
}

extension CardHeader where Trailing == EmptyView {
    init(icon: String, title: String, color: Color = doitGreen) {
        self.init(icon: icon, title: title, color: color) { EmptyView() }
    }
}

/// The main button: bright green with black writing.
struct BigButton: ButtonStyle {
    var height: CGFloat = 56
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                LinearGradient(colors: [doitGreenLight, doitGreen], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: doitGreen.opacity(enabled ? 0.45 : 0), radius: 14, y: 4)
            .opacity(enabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A quieter button: see-through with white writing.
struct SoftButton: ButtonStyle {
    var height: CGFloat = 52
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.09))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(enabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The big glowing ring for the minutes left today.
struct TimeRing: View {
    let left: Int
    let total: Int

    var body: some View {
        let part = total > 0 ? CGFloat(max(0, left)) / CGFloat(total) : 0
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 22)
            Circle()
                .trim(from: 0, to: part)
                .stroke(AngularGradient(colors: [doitGreenDark, doitGreen, doitGreenLight],
                                        center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * Double(max(part, 0.01)))),
                        style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: doitGreen.opacity(0.6), radius: 16)
                .animation(.easeOut(duration: 0.8), value: part)
            VStack(spacing: 0) {
                Text("\(max(0, left))")
                    .font(.system(size: 92, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                Text("MINUTES LEFT")
                    .font(.caption.weight(.heavy)).kerning(1.5)
                    .foregroundColor(doitGreen)
            }
        }
    }
}

/// A small number with a label under it, for the row under the ring.
struct Stat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .black, design: .rounded)).foregroundColor(.white)
            Text(label).font(.caption.weight(.semibold)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
