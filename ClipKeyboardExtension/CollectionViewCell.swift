//
//  CollectionViewCell.swift
//  TokenKeyboard
//
//  Created by hyunho lee on 2023/05/31.
//

import UIKit

protocol TextInput: AnyObject {
    func tapped(text: String, memoId: UUID)
}

class CollectionViewCell: UICollectionViewCell {

    weak var delegate: (any TextInput)?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.backgroundColor = .white
        label.textColor = .black
        label.layer.cornerRadius = AppTheme.paperLight.radiusSm  // 단일 코너 스케일 (sm=10, 테마 불변)
        label.layer.masksToBounds = true
        label.layer.borderWidth = 1.0
        label.layer.borderColor = UIColor.black.cgColor
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(titleLabel)
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapCell))
        addGestureRecognizer(tapGestureRecognizer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = contentView.bounds
    }
    
    func setTitle(_ title: String) {
        titleLabel.text = title
    }
    
    @objc func didTapCell() {

        if let index = clipKey.firstIndex(of: titleLabel.text!) {
            let tappedText = clipValue[index]
            let tappedMemoId = clipMemoId[index]
            delegate?.tapped(text: tappedText, memoId: tappedMemoId)
        }
    }
}
