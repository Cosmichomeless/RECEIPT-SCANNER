import Foundation

/// VAT (IVA) figures of a receipt. Every field is optional: only what the receipt shows,
/// or what follows exactly from it, is filled in.
public struct TaxBreakdown: Hashable, Sendable {
    /// Amount before tax.
    public var base: Decimal?
    /// Percentage, for example `21`. `nil` when the receipt mixes rates.
    public var rate: Decimal?
    /// Tax amount.
    public var amount: Decimal?
    /// `true` when `base` and `amount` were computed from the total and the rate
    /// (receipts that only say "IVA incluido 10%"), not read from the text.
    public var isEstimated: Bool

    public init(base: Decimal? = nil, rate: Decimal? = nil, amount: Decimal? = nil, isEstimated: Bool = false) {
        self.base = base
        self.rate = rate
        self.amount = amount
        self.isEstimated = isEstimated
    }

    public var isEmpty: Bool { base == nil && rate == nil && amount == nil }

    /// Rounding on the printed amounts can leave a cent or two of difference.
    public static let tolerance = Decimal(string: "0.02")!

    /// `false` only when base, tax and total are all known and base + tax does not give the total.
    public func isConsistent(withTotal total: Decimal?) -> Bool {
        guard let base, let amount, let total else { return true }
        let difference = base + amount - total
        return (difference < 0 ? -difference : difference) <= Self.tolerance
    }
}
