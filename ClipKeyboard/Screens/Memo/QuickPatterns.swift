//
//  QuickPatterns.swift
//  ClipKeyboard
//
//  새 메모 작성 허들을 낮추는 패턴 데이터 + 고스트 제안 카드.
//  계좌번호·주소·연락처처럼 예상되는 형식을 제목(키) + 구조화된 값 골격으로
//  미리 갖춰두고, 메인 화면에 "이런 메모는 어때요?" 흐릿한 카드로 제안한다.
//  로케일(ko/id/en)별로 실제 맥락에 맞는 골격을 제공한다.
//

import SwiftUI

/// 한 탭으로 채워지는 입력 형식.
struct QuickPattern: Identifiable {
    let id = UUID()
    let icon: String
    /// 제목(키) 제안.
    let title: String
    /// 값 골격 — 라벨만 둔 빈칸 또는 {플레이스홀더}.
    let scaffold: String

    static var defaults: [QuickPattern] {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        switch lang {
        case "ko": return korean
        case "id": return indonesian
        default:   return english
        }
    }

    private static let korean: [QuickPattern] = [
        QuickPattern(icon: "banknote.fill", title: "계좌번호",
                     scaffold: "은행: \n예금주: \n계좌번호: "),
        QuickPattern(icon: "creditcard.fill", title: "카드 정보",
                     scaffold: "카드번호: \n유효기간(MM/YY): "),
        QuickPattern(icon: "location.fill", title: "주소",
                     scaffold: "받는 분: \n연락처: \n주소: "),
        QuickPattern(icon: "person.crop.circle.fill", title: "연락처",
                     scaffold: "이름: \n전화: \n이메일: "),
        QuickPattern(icon: "wifi", title: "와이파이",
                     scaffold: "네트워크: \n비밀번호: "),
        QuickPattern(icon: "text.bubble.fill", title: "자기소개",
                     scaffold: "안녕하세요, {이름}입니다.\n{소속/직함}\n연락처: {연락처}"),
    ]

    private static let english: [QuickPattern] = [
        QuickPattern(icon: "banknote.fill", title: "Bank account",
                     scaffold: "Bank: \nName: \nAccount: "),
        QuickPattern(icon: "creditcard.fill", title: "Card info",
                     scaffold: "Card number: \nExpiry (MM/YY): "),
        QuickPattern(icon: "location.fill", title: "Address",
                     scaffold: "Recipient: \nPhone: \nAddress: "),
        QuickPattern(icon: "person.crop.circle.fill", title: "Contact",
                     scaffold: "Name: \nPhone: \nEmail: "),
        QuickPattern(icon: "wifi", title: "Wi-Fi",
                     scaffold: "Network: \nPassword: "),
        QuickPattern(icon: "text.bubble.fill", title: "Intro",
                     scaffold: "Hi, I'm {name}.\n{role / company}\nContact: {contact}"),
    ]

    private static let indonesian: [QuickPattern] = [
        QuickPattern(icon: "banknote.fill", title: "Rekening",
                     scaffold: "Bank: \nA/N: \nNo. Rekening: "),
        QuickPattern(icon: "creditcard.fill", title: "Kartu",
                     scaffold: "Nomor kartu: \nMasa berlaku (MM/YY): "),
        QuickPattern(icon: "location.fill", title: "Alamat",
                     scaffold: "Penerima: \nTelepon: \nAlamat: "),
        QuickPattern(icon: "person.crop.circle.fill", title: "Kontak",
                     scaffold: "Nama: \nTelepon: \nEmail: "),
        QuickPattern(icon: "wifi", title: "Wi-Fi",
                     scaffold: "Jaringan: \nKata sandi: "),
        QuickPattern(icon: "text.bubble.fill", title: "Perkenalan",
                     scaffold: "Halo, saya {nama}.\n{jabatan / perusahaan}\nKontak: {kontak}"),
    ]
}
