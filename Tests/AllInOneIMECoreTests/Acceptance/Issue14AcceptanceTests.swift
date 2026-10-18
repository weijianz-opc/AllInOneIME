import Foundation
import Testing
@testable import AllInOneIMECore

// Issue #14: `@calculate` gets `mod(a, b)`, the remainder of `a` divided by `b` with the sign of `b`, as calculators
// have it. It is exact in decimal like `+ - * /`, `mod(5, 0)` is a division by zero like `5/0`, the name works in any
// case, and anything but two arguments is wrong. `%` after a value still means percent.
struct Issue14AcceptanceTests {
    func result(_ expression: String) -> String? { try? Calculator.evaluate(expression) }

    func error(_ expression: String) -> Calculator.CalcError? {
        do {
            _ = try Calculator.evaluate(expression)
            return nil
        } catch {
            return error as? Calculator.CalcError
        }
    }

    func isBadArguments(_ error: Calculator.CalcError?) -> Bool {
        if case .badArguments = error { return true }
        return false
    }

    // MARK: - The examples in the issue

    @Test func theIssuesExamples() throws {
        #expect(try Calculator.evaluate("mod(17, 5)") == "2")
        #expect(try Calculator.evaluate("mod(-7, 3)") == "2")
        #expect(try Calculator.evaluate("mod(7, -3)") == "-2")
        #expect(try Calculator.evaluate("mod(7.5, 2)") == "1.5")
        #expect(try Calculator.evaluate("mod(0.3, 0.1)") == "0")
        #expect(throws: Calculator.CalcError.divisionByZero) { try Calculator.evaluate("mod(5, 0)") }
        #expect(try Calculator.evaluate("MOD(17, 5)") == "2")
        #expect(isBadArguments(error("mod(1)")), "\(String(describing: error("mod(1)")))")
        #expect(isBadArguments(error("mod(1, 2, 3)")), "\(String(describing: error("mod(1, 2, 3)")))")
    }

    // MARK: - The sign of the divisor

    @Test func theRemainderTakesTheSignOfTheDivisor() {
        let cases: [(String, String)] = [
            ("mod(17, 5)", "2"), ("mod(-17, 5)", "3"), ("mod(17, -5)", "-3"), ("mod(-17, -5)", "-2"),
            ("mod(-7, 3)", "2"), ("mod(7, -3)", "-2"), ("mod(-7, -3)", "-1"), ("mod(7, 3)", "1"),
            ("mod(3, 5)", "3"), ("mod(-3, 5)", "2"), ("mod(3, -5)", "-2"), ("mod(-3, -5)", "-3"),
            ("mod(1, 2)", "1"), ("mod(-1, 2)", "1"), ("mod(1, -2)", "-1"),
        ]
        for (expression, expected) in cases {
            #expect(result(expression) == expected, "\(expression) → \(String(describing: result(expression)))")
        }
    }

    @Test func noRemainderIsZeroWithoutASign() {
        // Whatever the signs, nothing left over is 0, never "-0".
        for expression in ["mod(15, 5)", "mod(-15, 5)", "mod(15, -5)", "mod(-15, -5)", "mod(0, 5)", "mod(0, -5)",
                           "mod(-6, 3)", "mod(6, -3)", "mod(5, 5)", "mod(-5, 5)", "mod(5, 1)", "mod(-5, 1)",
                           "mod(-sqrt(36), 3)", "mod(sqrt(36), -3)", "mod(-0, 3)"] {
            #expect(result(expression) == "0", "\(expression) → \(String(describing: result(expression)))")
        }
    }

    // MARK: - Exact decimals, like + - * /

    @Test func decimalsAreExact() {
        let cases: [(String, String)] = [
            ("mod(7.5, 2)", "1.5"), ("mod(-7.5, 2)", "0.5"), ("mod(7.5, -2)", "-0.5"), ("mod(-7.5, -2)", "-1.5"),
            ("mod(5.5, -2)", "-0.5"), ("mod(2.5, 1)", "0.5"), ("mod(-2.5, 1)", "0.5"),
            ("mod(0.3, 0.1)", "0"), ("mod(0.7, 0.1)", "0"), ("mod(1, 0.1)", "0"), ("mod(10, 0.1)", "0"),
            ("mod(0.75, 0.25)", "0"), ("mod(-0.3, 0.1)", "0"),
            ("mod(1, 0.3)", "0.1"), ("mod(-1, 0.3)", "0.2"), ("mod(1, -0.3)", "-0.2"),
            ("mod(1.1, 0.2)", "0.1"), ("mod(0.5, 0.3)", "0.2"), ("mod(0.1, 0.3)", "0.1"), ("mod(-0.1, 0.3)", "0.2"),
            ("mod(.5, .3)", "0.2"), ("mod(1e-3, 3e-4)", "0.0001"),
        ]
        for (expression, expected) in cases {
            #expect(result(expression) == expected, "\(expression) → \(String(describing: result(expression)))")
        }
    }

    @Test func wholeNumbersBeyondADoubleAreExact() {
        // A Double can't hold these (1e20 + 1 is 1e20 to it), but + - * / and whole powers keep every digit,
        // and so does mod.
        let cases: [(String, String)] = [
            ("mod(2^100, 7)", "2"), ("mod(2^100, 10)", "6"), ("mod(2^100, 1000)", "376"),
            ("mod(10^20 + 1, 7)", "3"), ("mod(-(10^20 + 1), 7)", "4"),
            ("mod(100000000000000000001, 7)", "3"),
            ("mod(123456789012345678901234567890, 11)", "7"),
            ("mod(123456789012345678901234567890, 9)", "0"),
        ]
        for (expression, expected) in cases {
            #expect(result(expression) == expected, "\(expression) → \(String(describing: result(expression)))")
        }
    }

    @Test func valuesThatAreNotExactStillGiveTheRemainder() throws {
        // Functions and constants are worked out in floating point; mod of them is the remainder all the same,
        // with no noise where the value shows as a whole number.
        #expect(result("mod(sqrt(16), 3)") == "1")
        #expect(result("mod(-sqrt(16), 3)") == "2")
        #expect(result("mod(sqrt(16), -3)") == "-2")
        #expect(result("mod(7, sqrt(9))") == "1")
        #expect(try Calculator.evaluate("sqrt(2)^2") == "2")
        #expect(result("mod(sqrt(2)^2, 2)") == "0")
        #expect(result("mod(pi, 1)") == (try Calculator.evaluate("pi-3")))
        #expect(result("mod(e, 1)") == (try Calculator.evaluate("e-2")))
        #expect(result("mod(-pi, 2)") == (try Calculator.evaluate("4-pi")))
    }

    // MARK: - Division by zero, as 5/0

    @Test func aZeroDivisorIsADivisionByZeroLikeFiveOverZero() {
        let plain = error("5/0")
        #expect(plain == .divisionByZero)
        for expression in ["mod(5, 0)", "mod(-5, 0)", "mod(0, 0)", "mod(5, 1-1)", "mod(5, 0.0)", "mod(5, -0)",
                           "mod(5, 0%)", "mod(2.5, 0)", "mod(sqrt(4), 0)", "mod(5, sqrt(0))", "MOD(5, 0)"] {
            #expect(error(expression) == plain, "\(expression) → \(String(describing: error(expression)))")
        }
        // It reads the same as 5/0's error.
        #expect(error("mod(5, 0)")?.errorDescription == plain?.errorDescription)
    }

    // MARK: - The name, in any case; the arguments

    @Test func theNameWorksInAnyCase() {
        for expression in ["mod(17, 5)", "MOD(17, 5)", "Mod(17, 5)", "mOd(17, 5)", "moD(17, 5)"] {
            #expect(result(expression) == "2", "\(expression) → \(String(describing: result(expression)))")
        }
        #expect(result("MOD(-7, 3)") == "2")
        #expect(result("Mod(7, -3)") == "-2")
    }

    @Test func anythingButTwoArgumentsIsWrong() {
        for expression in ["mod(1)", "mod(1, 2, 3)", "mod()", "MOD(1)", "Mod(1, 2, 3)", "mod(17)", "mod(1, 2, 3, 4)"] {
            let thrown = error(expression)
            #expect(isBadArguments(thrown), "\(expression) → \(String(describing: thrown))")
        }
        // Like every other function's.
        #expect(error("mod(1)") == .badArguments("mod"))
        #expect(error("mod(1, 2, 3)") == .badArguments("mod"))
        #expect(error("pow(2)") == .badArguments("pow"))
    }

    // MARK: - In an expression, as typed

    @Test func modIsAValueInsideAnExpression() {
        let cases: [(String, String)] = [
            ("mod(17, 5) * 3", "6"), ("1 + mod(17, 5)", "3"), ("10 - mod(17, 5)", "8"), ("mod(17, 5)^3", "8"),
            ("-mod(17, 5)", "-2"), ("mod(mod(17, 5), 3)", "2"), ("mod(10 + 7, 2 * 2 + 1)", "2"),
            ("mod(2^10, 1000)", "24"), ("mod(17, 5) + mod(-7, 3)", "4"), ("pow(mod(17, 5), 3)", "8"),
            ("max(mod(17, 5), mod(19, 5))", "4"), ("mod(abs(-17), 5)", "2"), ("(mod(17, 5))", "2"),
            ("mod((17), (5))", "2"), ("mod(-(7), 3)", "2"), ("mod(7, -(3))", "-2"), ("mod(+7, +3)", "1"),
            ("mod(17 , 5)", "2"), ("mod( 17,5 )", "2"), ("mod(17,5)", "2"), ("  mod(17, 5)  ", "2"),
            ("mod(17, 5)=", "2"), ("mod(17, 5) =", "2"),
        ]
        for (expression, expected) in cases {
            #expect(result(expression) == expected, "\(expression) → \(String(describing: result(expression)))")
        }
    }

    @Test func fullWidthTypingFromChineseWorks() {
        // Full-width letters, digits, parentheses and the Chinese comma count as their ASCII forms.
        for expression in ["mod(17，5)", "mod（17，5）", "ｍｏｄ（１７，５）", "ＭＯＤ（１７，　５）", "mod(17， 5)"] {
            #expect(result(expression) == "2", "\(expression) → \(String(describing: result(expression)))")
        }
        #expect(result("mod（－７，３）") == "2")
    }

    @Test func percentStillMeansPercent() {
        // `%` after a value is percent, as before; it is not the remainder.
        let cases: [(String, String)] = [
            ("50%", "0.5"), ("17%", "0.17"), ("200*5%", "10"), ("100+10%", "110"), ("100-10%", "90"),
            ("mod(50%, 0.3)", "0.2"), ("mod(17, 5)%", "0.02"),
        ]
        for (expression, expected) in cases {
            #expect(result(expression) == expected, "\(expression) → \(String(describing: result(expression)))")
        }
        #expect(result("17 % 5") != "2")
        #expect(result("17%5") != "2")
    }

    @Test func theOtherFunctionsAreAsTheyWere() {
        let cases: [(String, String)] = [
            ("pow(2, 10)", "1024"), ("min(3, 1, 2)", "1"), ("max(3, 1, 2)", "3"), ("round(3.14159, 2)", "3.14"),
            ("abs(-2)", "2"), ("floor(2.5)", "2"), ("ceil(2.5)", "3"), ("sqrt(16)", "4"), ("0.1+0.2", "0.3"),
            ("23*17", "391"), ("2^100", "1267650600228229401496703205376"),
        ]
        for (expression, expected) in cases {
            #expect(result(expression) == expected, "\(expression) → \(String(describing: result(expression)))")
        }
        #expect(error("pow(2)") == .badArguments("pow"))
        #expect(error("foo(17, 5)") == .unknownName("foo"))
    }

    // MARK: - As @calculate runs it

    @Test func theRunGivesTheRemainderAsItsOneCandidate() async throws {
        var texts: [String] = []
        var finals: [Bool] = []
        for try await update in Calculator.stream("mod(17, 5)") {
            texts.append(contentsOf: update.result.versions.map(\.text))
            finals.append(update.isFinal)
            #expect(update.rawText == "2")
        }
        #expect(texts == ["2"] && finals == [true])
    }

    @Test func theRunReportsADivisionByZeroAsForFiveOverZero() async {
        func thrown(_ expression: String) async -> Calculator.CalcError? {
            do {
                for try await _ in Calculator.stream(expression) {}
                return nil
            } catch {
                return error as? Calculator.CalcError
            }
        }
        let plain = await thrown("5/0")
        #expect(plain == .divisionByZero)
        #expect(await thrown("mod(5, 0)") == plain)
        #expect(isBadArguments(await thrown("mod(1)")))
        #expect(isBadArguments(await thrown("mod(1, 2, 3)")))
    }

    @Test func typingItAndPressingReturnRunsIt() {
        // In Chinese typing as in English: @calculate types Latin.
        let typings = [("@calculate mod(17, 5)", "mod(17, 5)"), ("@calculate MOD(-7, 3)", "MOD(-7, 3)"),
                       ("@calculate mod(7.5, 2)", "mod(7.5, 2)")]
        for (typed, input) in typings {
            for english in [true, false] {
                let c = Composer(engine: FakeEngine())
                if english { c.setInputMode(.english) }
                for ch in typed {
                    _ = c.handleKeyDown(ch == "@" ? acceptanceAt14 : ch == " " ? spaceKey : k(String(ch)))
                }
                #expect(c.draft == typed, "english: \(english)")
                let effects = c.handleKeyDown(enterKey).effects
                #expect(effects.first == .startRun(.calc, input: input, id: 1), "english: \(english), \(effects)")
            }
        }
    }

    // MARK: - Inside another command's text

    @Test func insideAnotherCommandsTextTheRemainderTakesItsPlace() throws {
        let catalog = Command.builtins
        let cases: [(String, String, String)] = [
            ("余数是 @calculate mod(17, 5) 个", "mod(17, 5)", "余数是 2 个"),
            ("the remainder is @calculate mod(17, 5) apples", "mod(17, 5)", "the remainder is 2 apples"),
            ("余数是 @calculate mod(17，5) 个", "mod(17，5)", "余数是 2 个"),
            ("余数是 @calculate MOD(-7, 3)。", "MOD(-7, 3)", "余数是 2。"),
            ("（余 @calculate mod(7, -3)）", "mod(7, -3)", "（余 -2）"),
        ]
        for (text, argument, filled) in cases {
            let plan = CommandPlan.make(text, commands: catalog)
            #expect(plan.inner.map(\.command) == [.calc], "\(text): \(plan)")
            #expect(plan.inner.map(\.argument) == [argument], "\(text): \(plan)")
            #expect(Calculator.failure(in: plan) == nil, "\(text)")
            let outputs = try plan.inner.map { try Calculator.evaluate($0.argument) }
            #expect(plan.input(outputs: outputs) == filled, "\(text) → \(plan.input(outputs: outputs))")
        }
    }

    @Test func insideAnotherCommandsTextADivisionByZeroIsSaidAtOnce() {
        let catalog = Command.builtins
        let plain = Calculator.failure(in: CommandPlan.make("总价是 @calculate 5/0 元", commands: catalog))
        #expect(plain == .divisionByZero)
        #expect(Calculator.failure(in: CommandPlan.make("余数是 @calculate mod(5, 0) 个", commands: catalog)) == plain)
        #expect(isBadArguments(Calculator.failure(in: CommandPlan.make("余数是 @calculate mod(5) 个", commands: catalog))))
    }
}

private let acceptanceAt14 = KeyEvent(keyCode: 0x13, characters: "@", charactersIgnoringModifiers: "@", modifiers: .shift)
