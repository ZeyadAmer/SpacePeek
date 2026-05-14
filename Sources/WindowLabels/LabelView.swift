import AppKit

final class LabelView: NSView {
    private let textField: NSTextField
    static let maxWidth: CGFloat = 78

    init(title: String) {
        let field = NSTextField(labelWithString: title)
        field.font = .systemFont(ofSize: 11, weight: .semibold)
        field.textColor = .white
        field.alignment = .center
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 2
        field.usesSingleLineMode = false
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.preferredMaxLayoutWidth = LabelView.maxWidth
        field.translatesAutoresizingMaskIntoConstraints = false

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.85)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 3
        field.shadow = shadow

        self.textField = field
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor),
            field.trailingAnchor.constraint(equalTo: trailingAnchor),
            field.topAnchor.constraint(equalTo: topAnchor),
            field.bottomAnchor.constraint(equalTo: bottomAnchor),
            field.widthAnchor.constraint(lessThanOrEqualToConstant: LabelView.maxWidth)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override var intrinsicContentSize: NSSize {
        let constrained = textField.sizeThatFits(NSSize(width: LabelView.maxWidth, height: .greatestFiniteMagnitude))
        return NSSize(width: min(constrained.width, LabelView.maxWidth), height: constrained.height)
    }
}
