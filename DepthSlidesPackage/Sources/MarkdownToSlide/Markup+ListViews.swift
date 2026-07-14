import Markdown
import SlideKit
import SwiftUI

extension Markup {
  // MARK: - List Views

  @MainActor
  func unorderedListView(_ list: UnorderedList) -> some View {
    ForEach(Array(list.listItems.enumerated()), id: \.offset) { _, listItem in
      listItemView(listItem)
    }
  }

  @MainActor
  func orderedListView(_ list: OrderedList) -> some View {
    ForEach(Array(list.listItems.enumerated()), id: \.offset) {
      index,
      listItem in
      orderedListItemView(listItem, index: index + Int(list.startIndex))
    }
  }

  @MainActor
  @ViewBuilder
  func listItemView(_ listItem: ListItem) -> some View {
    let hasNestedList = listItem.children.contains {
      $0 is UnorderedList || $0 is OrderedList
    }
    let url = listItem.containedURL

    VStack(alignment: .leading, spacing: 8) {
      if !hasNestedList {
        Item(label: {
          listItemTextView(listItem)
        })
      } else {
        Item(label: {
          listItemTextView(listItem)
        }) {
          ForEach(Array(listItem.children.enumerated()), id: \.offset) {
            _,
            child in
            if let unorderedList = child as? UnorderedList {
              ForEach(Array(unorderedList.listItems.enumerated()), id: \.offset) {
                _,
                nestedItem in
                listItemView(nestedItem)
              }
            } else if let orderedList = child as? OrderedList {
              ForEach(Array(orderedList.listItems.enumerated()), id: \.offset) {
                index,
                nestedItem in
                orderedListItemView(
                  nestedItem,
                  index: index + Int(orderedList.startIndex)
                )
              }
            }
          }
        }
      }

      if let url {
        LinkPreviewView(url: url)
      }
    }
  }

  @MainActor
  @ViewBuilder
  func orderedListItemView(_ listItem: ListItem, index: Int) -> some View {
    let hasNestedList = listItem.children.contains {
      $0 is UnorderedList || $0 is OrderedList
    }
    let url = listItem.containedURL

    VStack(alignment: .leading, spacing: 8) {
      if !hasNestedList {
        Item(
          accessory: .number(index),
          label: {
            listItemTextView(listItem)
          }
        )
      } else {
        Item(
          accessory: .number(index),
          label: {
            listItemTextView(listItem)
          }
        ) {
          ForEach(Array(listItem.children.enumerated()), id: \.offset) {
            _,
            child in
            if let unorderedList = child as? UnorderedList {
              ForEach(Array(unorderedList.listItems.enumerated()), id: \.offset) {
                _,
                nestedItem in
                listItemView(nestedItem)
              }
            } else if let orderedList = child as? OrderedList {
              ForEach(Array(orderedList.listItems.enumerated()), id: \.offset) {
                nestedIndex,
                nestedItem in
                orderedListItemView(
                  nestedItem,
                  index: nestedIndex + Int(orderedList.startIndex)
                )
              }
            }
          }
        }
      }

      if let url {
        LinkPreviewView(url: url)
      }
    }
  }

  func listItemText(_ listItem: ListItem) -> String {
    listItem.children
      .compactMap { child -> String? in
        if let paragraph = child as? Paragraph {
          return paragraph.children
            .compactMap { inline -> String? in
              if let text = inline as? Markdown.Text {
                return text.string
              }
              return nil
            }
            .joined()
        }
        return nil
      }
      .joined(separator: " ")
  }

  func listItemTextView(_ listItem: ListItem) -> SwiftUI.Text {
    listItem.children
      .compactMap { child -> SwiftUI.Text? in
        if let paragraph = child as? Paragraph {
          return paragraph.children
            .reduce(SwiftUI.Text("")) { SwiftUI.Text("\($0)\($1.toInlineText)") }
        }
        return nil
      }
      .reduce(SwiftUI.Text("")) { result, text in
        if result == SwiftUI.Text("") {
          return text
        } else {
          return SwiftUI.Text("\(result) \(text)")
        }
      }
  }
}
