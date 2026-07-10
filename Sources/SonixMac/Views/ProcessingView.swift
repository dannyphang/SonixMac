import SwiftUI

struct ProcessingView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .stroke(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing), lineWidth: 8)
                    .frame(width: 100, height: 100)
                    .rotationEffect(Angle(degrees: appState.isAnimating ? 360 : 0))
                    .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: appState.isAnimating)
                
                Image(systemName: "waveform")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            .onAppear {
                appState.isAnimating = true
            }
            
            VStack(spacing: 10) {
                Text("AI is processing...")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(appState.processingStatus)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Cancel") {
                appState.reset()
            }
            .buttonStyle(.link)
            .padding(.top, 20)
        }
        .padding(40)
    }
}
