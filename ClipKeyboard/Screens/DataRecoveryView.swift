//
//  DataRecoveryView.swift
//  ClipKeyboard
//
//  데이터 파일이 깨졌을 때 보여주는 복구 안내 - "전역 에러 폴백 화면".
//
//  왜 필요한가: 예전에는 저장 파일 디코딩이 실패하면 조용히 빈 목록이 떴다.
//  사용자 눈에는 "메모가 전부 사라진" 것으로 보이고, 그 상태에서 뭐라도 저장하면
//  빈 데이터가 파일에 덮여 **진짜로** 사라진다. 그래서
//   ① 사라진 게 아니라 못 읽은 것임을 알리고
//   ② 원본 사본을 보관해 뒀음을 밝히고
//   ③ 복원 경로(iCloud 백업 / 변경 기록)로 곧장 보낸다.
//
//  ⚠️ 이 화면이 떠 있는 동안 사용자가 새 메모를 저장하면 깨진 파일이 덮인다.
//     그래서 문구로 "먼저 복원을 시도하라"고 분명히 안내한다.
//

import SwiftUI

struct DataRecoveryView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    /// 격리 보관된 원본 파일명 (있으면 사용자에게 보여준다).
    private var quarantinedFile: String? {
        UserDefaults(suiteName: AppGroup.identifier)?
            .string(forKey: MemoStore.corruptionFileKey)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    HStack(spacing: 12) {
                        Image(systemName: AppSymbol.exclamationmarkTriangleFill)
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(NSLocalizedString("저장된 내용을 불러오지 못했어요", comment: "Data recovery title"))
                            .font(.title3.weight(.semibold))
                    }

                    Text(NSLocalizedString("단축어가 삭제된 게 아니라, 저장 파일을 읽지 못한 상태예요. 원본은 그대로 보관해 두었습니다.", comment: "Data recovery explanation"))
                        .foregroundColor(theme.textMuted)

                    Text(NSLocalizedString("새 단축어를 만들기 전에 먼저 복원을 시도해 주세요. 지금 저장하면 읽지 못한 파일을 덮어쓸 수 있어요.", comment: "Data recovery warning"))
                        .font(.callout)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(theme.radiusSm)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("복원 방법", comment: "Data recovery options header"))
                            .font(.headline)

                        NavigationLink(destination: CloudBackupView()) {
                            Label(NSLocalizedString("iCloud 백업에서 복원", comment: "Restore from iCloud backup"),
                                  systemImage: AppSymbol.icloudAndArrowUp)
                        }
                        NavigationLink(destination: MemoHistoryView()) {
                            Label(NSLocalizedString("변경 기록에서 되돌리기", comment: "Restore from change history"),
                                  systemImage: AppSymbol.clockArrowCirclepath)
                        }
                    }
                    .padding(.top, 4)

                    if let quarantinedFile {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(NSLocalizedString("보관된 원본", comment: "Quarantined original file header"))
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(theme.textMuted)
                            Text(quarantinedFile)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundColor(theme.textMuted)
                                .textSelection(.enabled)
                            Text(NSLocalizedString("복구가 어려우면 이 파일명과 함께 문의해 주세요.", comment: "Quarantined file support hint"))
                                .font(.footnote)
                                .foregroundColor(theme.textMuted)
                        }
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 12)
                }
                .padding(20)
            }
            .navigationTitle(NSLocalizedString("복구 안내", comment: "Data recovery navigation title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("확인", comment: "OK")) {
                        // 플래그만 지운다 - 격리 사본은 남겨 문의·재시도에 대비.
                        MemoStore.clearCorruptionFlag()
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
