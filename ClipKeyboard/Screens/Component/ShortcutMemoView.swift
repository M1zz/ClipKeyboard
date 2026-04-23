//
//  ShortcutMemoView.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/04.
//

import SwiftUI

struct ShortcutMemoView: View {

    @Environment(\.appTheme) private var theme

    @Binding var keyword: String
    @Binding var value: String
    @Binding var tokenMemos:[Memo]
    @Binding var originalData:[Memo]
    @Binding var showShortcutSheet: Bool
    var detectedType: ClipboardItemType = .text
    var confidence: Double = 0.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                #if canImport(UIKit)
                .foregroundColor(theme.surface)
                #else
                .foregroundColor(Color(NSColor.windowBackgroundColor))
                #endif
            HStack {
                VStack {
                    HStack {
                        Text(Constants.addNewToken)
                            .padding(.vertical, 5)
                            .font(.title3)
                            .bold()
                        Spacer()
                    }

                    // 자동 분류 타입 표시
                    HStack(spacing: 8) {
                        Image(systemName: detectedType.icon)
                            .font(.caption)
                            .foregroundColor(Color.fromName(detectedType.color))

                        Text(detectedType.localizedName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.fromName(detectedType.color).opacity(0.2))
                            .cornerRadius(6)

                        if confidence > 0.8 {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Text(value)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Spacer()

                    }
                }
                
                Button {
                    showShortcutSheet.toggle()
                } label: {
                    Image(systemName: "x.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30)
                        .padding(.horizontal)
                        .foregroundColor(.red)
                        
                }
                
                NavigationLink {
                    MemoAdd(insertedValue: value)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30)
                
                    
                        .foregroundColor(.green)
                }
            }
            .padding()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showShortcutSheet = false
                }
            }
        }
        .frame(maxHeight: 180)
        .padding()
        .transition(.move(edge: .bottom).combined(with: .opacity))
        //.presentationDetents([.height(200)])
    }

}

struct ShortcutMemoView_Previews: PreviewProvider {
    static var previews: some View {
        ShortcutMemoView(keyword: .constant("testKeyword"),
                         value: .constant("testValue"),
                         tokenMemos: .constant(Memo.dummyData),
                         originalData: .constant(Memo.dummyData),
                         showShortcutSheet: .constant(true))
    }
}
