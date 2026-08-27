//
//  CreateTrainerForm.swift
//  Create_Schedule_Kit
//
//  The three fields the Create New Trainer sheet collects, plus the rules that gate
//  "Add Trainer". Kept out of the view model so the gating is unit-testable on its own.
//

import Foundation

struct CreateTrainerForm: Equatable {

    var name: String = ""
    var email: String = ""
    var mobile: String = ""

    /// Mobile numbers are stored digits-only: the value doubles as the login id and as the
    /// `User/Exist` search text, so a stray space or dash would miss an existing account.
    static let mobileDigits = 10
    static let nameMinimum = 2

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedMobile: String { CreateTrainerForm.digits(in: mobile) }
}

// MARK: - Rules

extension CreateTrainerForm {

    /// Keeps only the digits — applied as the user types so the field cannot hold anything
    /// the existence check would fail to match on.
    static func digits(in text: String) -> String {
        text.filter(\.isNumber)
    }

    /// Caps the typed mobile at `mobileDigits` digits and drops everything else.
    static func sanitizedMobile(_ text: String) -> String {
        String(digits(in: text).prefix(mobileDigits))
    }

    static func isValidName(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).count >= nameMinimum
    }

    /// Deliberately permissive: one `@`, a non-empty local part, and a dotted domain. The
    /// server is the authority on deliverability — this only catches obvious typos before
    /// spending two round-trips on them.
    static func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace) else { return false }
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }) else { return false }
        // A bare TLD like "com." or "a@b.c" is not worth rejecting, but a 1-char TLD is a typo.
        return (labels.last?.count ?? 0) >= 2
    }

    static func isValidMobile(_ value: String) -> Bool {
        digits(in: value).count == mobileDigits
    }

    /// All three fields are required — the sheet marks every label with an asterisk.
    var isValid: Bool {
        CreateTrainerForm.isValidName(name)
            && CreateTrainerForm.isValidEmail(email)
            && CreateTrainerForm.isValidMobile(mobile)
    }

    /// First unmet requirement, in field order, for the warning toast on a blocked tap.
    var validationMessage: String? {
        if !CreateTrainerForm.isValidName(name) {
            return "Enter the trainer's name."
        }
        if !CreateTrainerForm.isValidEmail(email) {
            return "Enter a valid email address."
        }
        if !CreateTrainerForm.isValidMobile(mobile) {
            return "Enter a \(CreateTrainerForm.mobileDigits)-digit mobile number."
        }
        return nil
    }
}
