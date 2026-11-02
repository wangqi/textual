import Foundation
import Testing

@testable import Textual

struct PatternTokenizerTests {
  @Test func text() throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.emoji])

    // when
    let tokens = try tokenizer.tokenize("Hello world")

    // then
    #expect(
      tokens == [
        .init(type: .text, content: "Hello world")
      ]
    )
  }

  @Test func emoji() throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.emoji])

    // when
    let tokens = try tokenizer.tokenize("Hello :smile: and :heart: world")

    // then
    #expect(
      tokens == [
        .init(type: .text, content: "Hello "),
        .init(type: .emoji, content: ":smile:", capturedContent: "smile"),
        .init(type: .text, content: " and "),
        .init(type: .emoji, content: ":heart:", capturedContent: "heart"),
        .init(type: .text, content: " world"),
      ]
    )
  }

  @Test func adjacentEmoji() throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.emoji])

    // when
    let tokens = try tokenizer.tokenize("Hello :smile::heart: world")

    // then
    #expect(
      tokens == [
        .init(type: .text, content: "Hello "),
        .init(type: .emoji, content: ":smile:", capturedContent: "smile"),
        .init(type: .emoji, content: ":heart:", capturedContent: "heart"),
        .init(type: .text, content: " world"),
      ]
    )
  }

  @Test func incompleteEmoji() throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.emoji])

    // when
    let tokens = try tokenizer.tokenize("Hello :smile")

    // then
    #expect(
      tokens == [
        .init(type: .text, content: "Hello :smile")
      ]
    )
  }

  @Test func emptyEmoji() throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.emoji])

    // when
    let tokens = try tokenizer.tokenize("Hello :: world")

    // then
    #expect(
      tokens == [
        .init(type: .text, content: "Hello :: world")
      ]
    )
  }

  @Test func invalidEmoji() throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.emoji])

    // when
    let tokens = try tokenizer.tokenize("Hello :not emoji: :notemoji!: world")

    // then
    #expect(
      tokens == [
        .init(type: .text, content: "Hello :not emoji: :notemoji!: world")
      ]
    )
  }

  @Test func preservesNewlines() throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.emoji])

    // when
    let tokens = try tokenizer.tokenize(
      """
      Some line
      Hello :smile: and :heart: world
      Another line
      """
    )

    // then
    #expect(
      tokens == [
        .init(type: .text, content: "Some line\nHello "),
        .init(type: .emoji, content: ":smile:", capturedContent: "smile"),
        .init(type: .text, content: " and "),
        .init(type: .emoji, content: ":heart:", capturedContent: "heart"),
        .init(type: .text, content: " world\nAnother line"),
      ]
    )
  }

  @Test func inlineMath() throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.mathBlock, .mathInline])

    // when
    let tokens = try tokenizer.tokenize("Euler: $e^{i\\pi}+1=0$.")

    // then
    #expect(
      tokens == [
        .init(type: .text, content: "Euler: "),
        .init(type: .mathInline, content: "$e^{i\\pi}+1=0$", capturedContent: "e^{i\\pi}+1=0"),
        .init(type: .text, content: "."),
      ]
    )
  }

  @Test func inlineMathEscapedDollar() throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.mathBlock, .mathInline])

    // when
    let tokens = try tokenizer.tokenize("Cost: $a\\$b$")

    // then
    #expect(
      tokens == [
        .init(type: .text, content: "Cost: "),
        .init(type: .mathInline, content: "$a\\$b$", capturedContent: "a\\$b"),
      ]
    )
  }

  @Test func blockMath() throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.mathBlock, .mathInline])

    // when
    let tokens = try tokenizer.tokenize(
      """
      Before
      $$E = mc^2$$
      After
      """
    )

    // then
    #expect(
      tokens == [
        .init(type: .text, content: "Before\n"),
        .init(type: .mathBlock, content: "$$E = mc^2$$", capturedContent: "E = mc^2"),
        .init(type: .text, content: "\nAfter"),
      ]
    )
  }

  @Test func blockMathPreferredOverInline() throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.mathBlock, .mathInline])

    // when
    let tokens = try tokenizer.tokenize("$$x+1$$")

    // then
    #expect(
      tokens == [
        .init(type: .mathBlock, content: "$$x+1$$", capturedContent: "x+1")
      ]
    )
  }

  // Currency amounts must stay text (pandoc inline-math rule). // wangqi modified 2026-10-27
  @Test(arguments: [
    "$12.99/month or $129/year",
    "$5 and $10",
    "($10-$20)",
    "$10/$20",
  ])
  func currencyStaysText(_ input: String) throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.mathBlock, .mathInline])

    // when
    let tokens = try tokenizer.tokenize(input)

    // then
    #expect(tokens == [.init(type: .text, content: input)])
  }

  // Single-character and multiple inline math spans still parse. // wangqi modified 2026-10-27
  @Test func inlineMathSingleCharacter() throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.mathBlock, .mathInline])

    // when
    let tokens = try tokenizer.tokenize("$x$")

    // then
    #expect(tokens == [.init(type: .mathInline, content: "$x$", capturedContent: "x")])
  }

  // wangqi modified 2026-10-27
  @Test func inlineMathTwoSpans() throws {
    // given
    let tokenizer = PatternTokenizer(patterns: [.mathBlock, .mathInline])

    // when
    let tokens = try tokenizer.tokenize("$a+b$ and $c$")

    // then
    #expect(
      tokens == [
        .init(type: .mathInline, content: "$a+b$", capturedContent: "a+b"),
        .init(type: .text, content: " and "),
        .init(type: .mathInline, content: "$c$", capturedContent: "c"),
      ]
    )
  }
}
