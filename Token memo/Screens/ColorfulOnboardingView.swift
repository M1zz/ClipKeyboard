//
//  ColorfulOnboardingView.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/15.
//

import SwiftUI

/// Shows a full color background for each onboarding view
struct ColorfulOnboardingView: View {

    @State var pages = [PageDetails]()
    @State private var pageIndex: Int = 0
    private let bottomSectionHeight: CGFloat = 100
    var exitAction: () -> Void
    @State private var showSettingsAlert = false
    
    // MARK: - Main rendering function
    var body: some View {
        ZStack {
            ScrollView {
                TabView(selection: $pageIndex.animation(.easeIn)) {
                    ForEach(0..<pages.count, id: \.self, content: { index in
                        CreatePage(details: pages[index])
                    })
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: UIScreen.main.bounds.height)
            }.edgesIgnoringSafeArea(.all).onAppear {
                UIScrollView.appearance().bounces = false
            }
            BottomSectionView
        }
        .alert("설정으로 이동", isPresented: $showSettingsAlert) {
            Button("취소", role: .cancel) {}
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("설정 앱에서 키보드를 추가하고 전체 접근 권한을 허용해주세요.")
        }
    }
    
    // MARK: - Configuration
    struct PageDetails {
        let imageName: String
        let title: String
        let subtitle: String
        let color: Color
    }
    
    /// Create a page with details
    private func CreatePage(details: PageDetails) -> some View {
        let imageSize = UIScreen.main.bounds.width-80
        return ZStack {
            details.color
            VStack {
                Spacer() /// Image section
                if UIImage(named: details.imageName) != nil {
                    Image(uiImage: UIImage(named: details.imageName)!)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(width: imageSize, alignment: .center)
                } else {
                    Color.clear.frame(height: imageSize)
                }
                Spacer() /// Text section
                VStack(spacing: 20) {
                    Text(details.title).font(.system(size: 35, weight: .semibold, design: .rounded))
                    Text(details.subtitle).font(.system(size: 18))
                }
                Spacer()
                Color.clear.frame(height: bottomSectionHeight+50)
            }.padding().multilineTextAlignment(.center)
        }.frame(width: UIScreen.main.bounds.width).foregroundColor(.white)
    }
    
    /// Page dots and CTA buttons view
    private var BottomSectionView: some View {
        let pageDotSize: CGFloat = 10
        return VStack {
            Spacer()
            VStack {
                /// Page dots section
                HStack {
                    ForEach(0..<pages.count, id: \.self, content: { id in
                        ZStack {
                            if pageIndex == id {
                                RoundedRectangle(cornerRadius: 20).frame(width: pageDotSize * 3)
                            } else {
                                Circle().frame(width: pageDotSize)
                            }
                        }.frame(height: pageDotSize)
                    })
                }.foregroundColor(.white)

                /// Settings button
                Button(action: {
                    showSettingsAlert = true
                }, label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("설정으로 이동")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(25)
                })

                Spacer()
                /// Next button
                HStack {
                    Spacer()
                    Button(action: {
                        UIImpactFeedbackGenerator().impactOccurred()
                        if pageIndex < pages.count - 1 {
                            withAnimation { pageIndex = pageIndex + 1 }
                        } else {
                            exitAction()
                        }
                    }, label: {
                        if pageIndex == pages.count - 1 {
                            Text("Get Started").foregroundColor(pages[pageIndex].color)
                                .padding().padding([.leading, .trailing]).background(
                                RoundedRectangle(cornerRadius: 40)
                            )
                        } else {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                    }).frame(height: 40).font(.system(size: 20, weight: .semibold))
                    if pageIndex == pages.count - 1 {
                        Spacer()
                    }
                }.padding()
            }.foregroundColor(.white).frame(height: bottomSectionHeight).padding(.bottom)
        }
    }
}

// MARK: - Preview UI
struct ColorfulOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        let pages = [
        ColorfulOnboardingView.PageDetails.init(imageName: "step1", title: "Enable Keyboard", subtitle: "Go to Settings -> General -> Keyboard -> Keyboards then tap 'Add New Keyboard...' and select 'Token Memo'", color: Color(#colorLiteral(red: 0.4534527972, green: 0.5727163462, blue: 1, alpha: 1))),
            ColorfulOnboardingView.PageDetails.init(imageName: "step2", title: "Add your Text", subtitle: "In the Token Memo app, tap the '+' button to add your own text/phrase. To delete any added text, you can swipe left to delete.", color: Color(#colorLiteral(red: 0.9011964598, green: 0.5727163462, blue: 0, alpha: 1))),
            ColorfulOnboardingView.PageDetails.init(imageName: "step3", title: "Use the Keyboard", subtitle: "In the messages app, email or any other app, you can tap the 'globe' icon to switch between keyboards. Enjoy!", color: Color(#colorLiteral(red: 0.4534527972, green: 0.7018411277, blue: 0.06370192308, alpha: 1)))
        ]
        return ColorfulOnboardingView(pages: pages, exitAction: { })
    }
}
//
//  UseCaseSelectionView.swift
//  Token memo
//
//  Created by Claude
//

import SwiftUI

/// 사용자의 주요 사용 사례를 선택하는 온보딩 화면
struct UseCaseSelectionView: View {
    @ObservedObject var memoStore = MemoStore.shared
    @State private var selectedUseCases: Set<UseCase> = []
    @State private var isComplete = false

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.top, 60)

                Text("무엇을 자주 입력하세요?")
                    .font(.system(size: 28, weight: .bold))

                Text("선택하신 항목에 맞는 템플릿을 자동으로 추가해드려요")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)

            // 사용 사례 선택 그리드
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(UseCase.allCases, id: \.self) { useCase in
                        UseCaseCard(
                            useCase: useCase,
                            isSelected: selectedUseCases.contains(useCase)
                        ) {
                            toggleSelection(useCase)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            // 하단 버튼
            VStack(spacing: 12) {
                Button {
                    createTemplatesForSelectedUseCases()
                    withAnimation {
                        isComplete = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onComplete()
                    }
                } label: {
                    HStack {
                        Text(selectedUseCases.isEmpty ? "건너뛰기" : "시작하기 (\(selectedUseCases.count)개 선택)")
                            .font(.system(size: 18, weight: .semibold))
                        if !selectedUseCases.isEmpty {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedUseCases.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)

                if !selectedUseCases.isEmpty {
                    Button("나중에 직접 추가할게요") {
                        onComplete()
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 40)
        }
    }

    private func toggleSelection(_ useCase: UseCase) {
        if selectedUseCases.contains(useCase) {
            selectedUseCases.remove(useCase)
        } else {
            selectedUseCases.insert(useCase)
        }
    }

    private func createTemplatesForSelectedUseCases() {
        var allTemplates: [Memo] = []
        for useCase in selectedUseCases {
            allTemplates.append(contentsOf: useCase.templates)
        }
        if !allTemplates.isEmpty {
            do {
                try memoStore.save(memos: allTemplates, type: .tokenMemo)
                print("✅ 템플릿 \(allTemplates.count)개 저장 완료")
            } catch {
                print("❌ 템플릿 저장 실패: \(error)")
            }
        }
    }
}

// MARK: - Use Case Card
struct UseCaseCard: View {
    let useCase: UseCase
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? useCase.color : Color(.systemGray6))
                        .frame(width: 70, height: 70)

                    Image(systemName: useCase.icon)
                        .font(.system(size: 32))
                        .foregroundColor(isSelected ? .white : .gray)
                }

                Text(useCase.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text(useCase.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? useCase.color.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? useCase.color : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Use Case Model
enum UseCase: String, CaseIterable {
    case shopping = "shopping"
    case overseas = "overseas"
    case signup = "signup"
    case work = "work"

    var title: String {
        switch self {
        case .shopping: return "쇼핑/배달"
        case .overseas: return "해외직구"
        case .signup: return "서비스 가입"
        case .work: return "업무/지원서"
        }
    }

    var subtitle: String {
        switch self {
        case .shopping: return "주소, 전화번호,\n배송 메시지"
        case .overseas: return "영문 주소,\n통관부호, 카드"
        case .signup: return "이메일, 전화번호,\n개인정보"
        case .work: return "이력서, 지원서,\n업무 정보"
        }
    }

    var icon: String {
        switch self {
        case .shopping: return "cart.fill"
        case .overseas: return "airplane"
        case .signup: return "person.crop.circle.badge.checkmark"
        case .work: return "briefcase.fill"
        }
    }

    var color: Color {
        switch self {
        case .shopping: return .orange
        case .overseas: return .blue
        case .signup: return .green
        case .work: return .purple
        }
    }

    var templates: [Memo] {
        switch self {
        case .shopping:
            return [
                Memo(
                    title: "배송지 주소",
                    value: "{시/도} {구/동} {상세주소}",
                    category: "주소",
                    isTemplate: true,
                    templateVariables: ["{시/도}", "{구/동}", "{상세주소}"]
                ),
                Memo(
                    title: "받는 분 전화번호",
                    value: "010-",
                    category: "전화번호"
                ),
                Memo(
                    title: "배송 요청사항",
                    value: "부재 시 문 앞에 놓아주세요",
                    category: "텍스트"
                ),
                Memo(
                    title: "배송 요청사항 (택배함)",
                    value: "경비실 택배함에 넣어주세요",
                    category: "텍스트"
                )
            ]

        case .overseas:
            return [
                Memo(
                    title: "영문 이름",
                    value: "{First Name} {Last Name}",
                    category: "이름",
                    isTemplate: true,
                    templateVariables: ["{First Name}", "{Last Name}"]
                ),
                Memo(
                    title: "영문 주소",
                    value: "{상세주소}, {시/구}, {시/도}, {우편번호}, South Korea",
                    category: "주소",
                    isTemplate: true,
                    templateVariables: ["{상세주소}", "{시/구}", "{시/도}", "{우편번호}"]
                ),
                Memo(
                    title: "통관고유부호",
                    value: "P",
                    category: "통관부호"
                ),
                Memo(
                    title: "카드번호",
                    value: "",
                    category: "카드번호",
                    isSecure: true
                )
            ]

        case .signup:
            return [
                Memo(
                    title: "이메일",
                    value: "",
                    category: "이메일"
                ),
                Memo(
                    title: "전화번호",
                    value: "010-",
                    category: "전화번호"
                ),
                Memo(
                    title: "주소",
                    value: "{시/도} {구/동} {상세주소}",
                    category: "주소",
                    isTemplate: true,
                    templateVariables: ["{시/도}", "{구/동}", "{상세주소}"]
                ),
                Memo(
                    title: "생년월일",
                    value: "",
                    category: "생년월일"
                ),
                Memo(
                    title: "주민등록번호",
                    value: "",
                    category: "주민등록번호",
                    isSecure: true
                )
            ]

        case .work:
            return [
                Memo(
                    title: "이름",
                    value: "",
                    category: "이름"
                ),
                Memo(
                    title: "생년월일",
                    value: "",
                    category: "생년월일"
                ),
                Memo(
                    title: "이메일",
                    value: "",
                    category: "이메일"
                ),
                Memo(
                    title: "전화번호",
                    value: "010-",
                    category: "전화번호"
                ),
                Memo(
                    title: "주소",
                    value: "{시/도} {구/동} {상세주소}",
                    category: "주소",
                    isTemplate: true,
                    templateVariables: ["{시/도}", "{구/동}", "{상세주소}"]
                ),
                Memo(
                    title: "자기소개",
                    value: "{직무}에 지원하는 {이름}입니다.",
                    category: "텍스트",
                    isTemplate: true,
                    templateVariables: ["{직무}", "{이름}"]
                )
            ]
        }
    }
}

// MARK: - Preview
struct UseCaseSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        UseCaseSelectionView(onComplete: {})
    }
}
