import SwiftUI

// MARK: - Shimmer Animation Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    let width = geo.size.width
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.4), location: 0.5),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.6)
                    .offset(x: width * phase)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 1.5)
                            .repeatForever(autoreverses: false)
                        ) {
                            phase = 2.0
                        }
                    }
                }
                .clipped()
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Building Blocks

struct SkeletonBox: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.primary.opacity(0.08))
            .frame(width: width, height: height)
            .shimmer()
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: size, height: size)
            .shimmer()
    }
}

// MARK: - Dashboard Skeleton

struct DashboardSkeletonView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Hero spending card skeleton
            VStack(spacing: 16) {
                SkeletonBox(width: 160, height: 12)
                SkeletonBox(width: 200, height: 42, cornerRadius: 10)
                SkeletonBox(height: 10, cornerRadius: 5)
                HStack {
                    SkeletonBox(width: 140, height: 14)
                    Spacer()
                    SkeletonBox(width: 100, height: 14)
                }
            }
            .padding(22)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22))

            // Presto card skeleton
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SkeletonCircle(size: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonBox(width: 70, height: 12)
                        SkeletonBox(width: 50, height: 8)
                    }
                    Spacer()
                    SkeletonBox(width: 20, height: 14)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBox(width: 80, height: 8)
                        SkeletonBox(width: 140, height: 32, cornerRadius: 8)
                    }
                    Spacer()
                    SkeletonBox(width: 80, height: 34, cornerRadius: 17)
                }
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color(hex: "0F291E"), Color(hex: "0A1A14"), Color(hex: "06100C")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))

            // Category spending skeleton
            VStack(alignment: .leading, spacing: 14) {
                SkeletonBox(width: 120, height: 10)
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 10) {
                        SkeletonBox(width: 30, height: 30, cornerRadius: 8)
                        SkeletonBox(width: 80, height: 14)
                        Spacer()
                        SkeletonBox(width: 60, height: 14)
                    }
                }
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Pacing stats skeleton
            HStack(spacing: 12) {
                pacingTileSkeleton
                pacingTileSkeleton
            }
        }
    }

    private var pacingTileSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonBox(width: 20, height: 14)
            VStack(alignment: .leading, spacing: 4) {
                SkeletonBox(width: 80, height: 22, cornerRadius: 6)
                SkeletonBox(width: 60, height: 10)
                SkeletonBox(width: 70, height: 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Transaction List Skeleton

struct TransactionSkeletonView: View {
    var body: some View {
        List {
            ForEach(0..<3, id: \.self) { section in
                Section {
                    ForEach(0..<(section == 0 ? 3 : 2), id: \.self) { _ in
                        transactionRowSkeleton
                    }
                } header: {
                    SkeletonBox(width: 80, height: 12)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var transactionRowSkeleton: some View {
        HStack(spacing: 14) {
            SkeletonBox(width: 40, height: 40, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBox(width: 120, height: 14)
                SkeletonBox(width: 80, height: 10)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                SkeletonBox(width: 60, height: 14)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Analytics Skeleton

struct AnalyticsSkeletonView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Total spent card skeleton
            VStack(spacing: 12) {
                SkeletonBox(width: 140, height: 10)
                SkeletonBox(width: 180, height: 36, cornerRadius: 8)
                HStack {
                    SkeletonBox(width: 100, height: 12)
                    Spacer()
                    SkeletonBox(width: 80, height: 12)
                }
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Chart area skeleton
            VStack(alignment: .leading, spacing: 12) {
                SkeletonBox(width: 140, height: 12)
                SkeletonBox(height: 180, cornerRadius: 12)
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Daily spending skeleton
            VStack(alignment: .leading, spacing: 12) {
                SkeletonBox(width: 120, height: 12)
                SkeletonBox(height: 140, cornerRadius: 12)
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Payment methods skeleton
            VStack(alignment: .leading, spacing: 12) {
                SkeletonBox(width: 160, height: 12)
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 10) {
                        SkeletonCircle(size: 28)
                        SkeletonBox(width: 80, height: 14)
                        Spacer()
                        SkeletonBox(width: 60, height: 14)
                    }
                }
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}
