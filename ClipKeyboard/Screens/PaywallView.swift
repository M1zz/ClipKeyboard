//
//  PaywallView.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2026/02/21.
//

import SwiftUI
import StoreKit

/// Paywall — Pro 업그레이드 화면
/// 제한 도달 시 자연스럽게 표시
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreManager.shared
    
    /// 어떤 제한 때문에 보여주는지 (nil이면 일반 업그레이드)
    var triggeredBy: ProFeatureManager.LimitType?
    
    @State private var showSuccessAnimation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - 헤더
                    headerSection
                    
                    // MARK: - 제한 안내 (트리거된 경우)
                    if let trigger = triggeredBy {
                        limitBanner(trigger)
                    }
                    
                    // MARK: - 기능 비교
                    featureComparison
                    
                    // MARK: - 구매 버튼
                    purchaseSection
                    
                    // MARK: - 하단 정보
                    footerSection
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay {
            if showSuccessAnimation {
                successOverlay
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow.gradient)
            
            Text("ClipKeyboard Pro")
                .font(.title)
                .fontWeight(.bold)
            
            Text(NSLocalizedString("한번 구매, 평생 사용", comment: "One-time purchase"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Limit Banner
    
    private func limitBanner(_ limit: ProFeatureManager.LimitType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
            
            Text(limit.localizedDescription)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Feature Comparison
    
    private var featureComparison: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text(NSLocalizedString("기능", comment: "Feature"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(NSLocalizedString("무료", comment: "Free"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(width: 60)
                
                Text("Pro")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .frame(width: 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            // 행들
            featureRow(NSLocalizedString("메모 저장", comment: "Memo"),
                       free: String(format: NSLocalizedString("%d개", comment: "count unit"), ProFeatureManager.freeMemoLimit),
                       pro: NSLocalizedString("무제한", comment: "Unlimited"))
            
            featureRow(NSLocalizedString("콤보", comment: "Combo"),
                       free: String(format: NSLocalizedString("%d개", comment: "count unit"), ProFeatureManager.freeComboLimit),
                       pro: NSLocalizedString("무제한", comment: "Unlimited"))
            
            featureRow(NSLocalizedString("템플릿", comment: "Template"),
                       free: String(format: NSLocalizedString("%d개", comment: "count unit"), ProFeatureManager.freeTemplateLimit),
                       pro: NSLocalizedString("무제한", comment: "Unlimited"))
            
            featureRow(NSLocalizedString("클립보드 기록", comment: "Clipboard"),
                       free: String(format: NSLocalizedString("%d개", comment: "count unit"), ProFeatureManager.freeClipboardHistoryLimit),
                       pro: String(format: NSLocalizedString("%d개", comment: "count unit"), 100))
            
            featureRow(NSLocalizedString("iCloud 백업", comment: "iCloud"),
                       free: "—", pro: "✓", isProOnly: true)
            
            featureRow(NSLocalizedString("생체인증 잠금", comment: "Biometric"),
                       free: "—", pro: "✓", isProOnly: true)
            
            featureRow(NSLocalizedString("테마 설정", comment: "Theme"),
                       free: "—", pro: "✓", isProOnly: true)
            
            featureRow(NSLocalizedString("이미지 메모", comment: "Image"),
                       free: "—", pro: "✓", isProOnly: true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    private func featureRow(_ name: String, free: String, pro: String, isProOnly: Bool = false) -> some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(free)
                .font(.subheadline)
                .foregroundStyle(isProOnly ? .secondary : .primary)
                .frame(width: 60)
            
            Text(pro)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.orange)
                .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Purchase
    
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if store.isPro {
                // 이미 Pro
                Label(NSLocalizedString("Pro 활성화됨", comment: "Pro active"),
                      systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding()
            } else {
                // 구매 버튼
                Button {
                    Task {
                        let success = await store.purchasePro()
                        if success {
                            withAnimation(.spring(response: 0.4)) {
                                showSuccessAnimation = true
                            }
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        if store.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(priceText)
                                .fontWeight(.bold)
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(height: 54)
                    .frame(maxWidth: .infinity)
                    .background(.orange.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(store.isLoading)
                
                // 복원 버튼
                Button {
                    Task { await store.restorePurchases() }
                } label: {
                    Text(NSLocalizedString("이전 구매 복원", comment: "Restore"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // 에러 메시지
                if let error = store.purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
    
    private var priceText: String {
        if let product = store.proProduct {
            return String(format: NSLocalizedString("Pro 업그레이드 — %@", comment: "Price"), product.displayPrice)
        }
        return NSLocalizedString("Pro 업그레이드", comment: "Upgrade")
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        VStack(spacing: 4) {
            Text(NSLocalizedString("일회성 결제 · 구독 없음 · 환불 가능", comment: "Purchase info"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                
                Text(NSLocalizedString("Pro 활성화 완료!", comment: "Pro activated"))
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .transition(.opacity)
    }
}

// MARK: - Paywall Modifier

/// 제한 도달 시 자동으로 Paywall을 띄우는 ViewModifier
struct PaywallModifier: ViewModifier {
    @Binding var isPresented: Bool
    var limitType: ProFeatureManager.LimitType?
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                PaywallView(triggeredBy: limitType)
                    .presentationDetents([.large])
            }
    }
}

extension View {
    /// Paywall 시트를 쉽게 붙이는 modifier
    func paywall(isPresented: Binding<Bool>, triggeredBy: ProFeatureManager.LimitType? = nil) -> some View {
        modifier(PaywallModifier(isPresented: isPresented, limitType: triggeredBy))
    }
}

#Preview {
    PaywallView(triggeredBy: .memo)
}
