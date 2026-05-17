import AppKit

final class LabelView: NSView {
    private let textField: NSTextField
    static let maxWidth: CGFloat = 140

    init(title: String, style: LabelStyle = PreferencesStore.shared.preferences.labelStyle) {
        let field = NSTextField(labelWithString: title)
        field.font = style.makeFont()
        field.textColor = .white
        field.alignment = .center
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 1
        field.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = false
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
            field.centerYAnchor.constraint(equalTo: centerYAnchor),
            field.widthAnchor.constraint(lessThanOrEqualToConstant: LabelView.maxWidth)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override var intrinsicContentSize: NSSize {
        let big = CGFloat.greatestFiniteMagnitude
        let natural = textField.sizeThatFits(NSSize(width: big, height: big))
        return NSSize(width: min(natural.width, LabelView.maxWidth), height: max(natural.height, 16))
    }
}
