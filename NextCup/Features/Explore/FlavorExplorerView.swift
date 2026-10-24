import NextCupKit
import SwiftData
import SwiftUI

/// The flavor explorer: every bucket of the shared vocabulary, grouped by
/// dimension. A bucket opens to the words that map to it, the beans that carry
/// it, and the buckets those beans also carry, each one a link onward.
struct FlavorExplorerView: View {
  let taxonomy: Taxonomy

  private static let sections: [(Taxonomy.Dimension, String)] = [
    (.flavor, "Flavors"), (.origin, "Origins"), (.process, "Processes"),
    (.roast, "Roasts"), (.brewer, "Brewers"),
  ]

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: DS.Space.lg) {
        ForEach(Self.sections, id: \.0) { dimension, title in
          VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text(title.uppercased()).font(DS.Font.label).foregroundStyle(DS.ink2)
              .accessibilityAddTraits(.isHeader)
            PaperBox {
              VStack(spacing: 0) {
                let buckets = taxonomy.buckets(in: dimension)
                ForEach(Array(buckets.enumerated()), id: \.element.key) { index, bucket in
                  if index > 0 { Hairline() }
                  BucketLink(taxonomy: taxonomy, ref: BucketRef(bucket, in: dimension))
                }
              }
            }
          }
        }
      }
      .padding(DS.Space.lg)
    }
    .background(DS.bg)
    .navigationTitle("Flavor explorer")
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("flavor.list")
  }
}

/// A row that opens one bucket.
private struct BucketLink: View {
  let taxonomy: Taxonomy
  let ref: BucketRef

  var body: some View {
    NavigationLink {
      BucketDetailView(taxonomy: taxonomy, ref: ref)
    } label: {
      HStack {
        Text(ref.name).font(DS.Font.headline).foregroundStyle(DS.ink)
        Spacer(minLength: DS.Space.sm)
        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(DS.ink2)
          .accessibilityHidden(true)
      }
      .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
      .padding(.horizontal, DS.Space.md)
      .contentShape(Rectangle())
    }
    .accessibilityIdentifier("flavor.bucket.\(ref.dimension.rawValue).\(ref.key)")
  }
}

private struct BucketDetailView: View {
  let taxonomy: Taxonomy
  let ref: BucketRef

  @Query(sort: \Bean.name) private var beans: [Bean]
  @Query private var storedAliases: [TaxonomyAlias]

  var body: some View {
    let aliases = ExploreModel.aliases(storedAliases)
    let carriers = beans.filter {
      ExploreModel.buckets(of: $0, taxonomy: taxonomy, aliases: aliases).contains(ref)
    }
    let related = relatedBuckets(of: carriers, aliases: aliases)
    ScrollView {
      LazyVStack(alignment: .leading, spacing: DS.Space.lg) {
        section("Words that map here") {
          let words = words(aliases)
          if words.isEmpty {
            Text("No words are mapped to this bucket yet.").font(.callout)
              .foregroundStyle(DS.ink2)
          } else {
            Text(words.joined(separator: "  ·  ")).font(.callout).foregroundStyle(DS.ink)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        section("Your beans") {
          if carriers.isEmpty {
            Text("None of your beans carry this yet.").font(.callout).foregroundStyle(DS.ink2)
          } else {
            PaperBox {
              VStack(spacing: 0) {
                ForEach(Array(carriers.enumerated()), id: \.element.id) { index, bean in
                  if index > 0 { Hairline() }
                  NavigationLink(value: DeepLink.bean(bean.id)) {
                    Text(bean.name).font(DS.Font.headline).foregroundStyle(DS.ink)
                      .frame(maxWidth: .infinity, minHeight: DS.Size.minTap, alignment: .leading)
                      .padding(.horizontal, DS.Space.md)
                      .contentShape(Rectangle())
                  }
                }
              }
            }
          }
        }
        if !related.isEmpty {
          section("Seen together on your beans") {
            PaperBox {
              VStack(spacing: 0) {
                ForEach(Array(related.enumerated()), id: \.element) { index, other in
                  if index > 0 { Hairline() }
                  BucketLink(taxonomy: taxonomy, ref: other)
                }
              }
            }
          }
        }
      }
      .padding(DS.Space.lg)
    }
    .background(DS.bg)
    .navigationTitle(ref.name)
    .navigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("flavor.detail.\(ref.dimension.rawValue).\(ref.key)")
  }

  /// Bundled words plus the user's own aliases for this bucket.
  private func words(_ aliases: [Taxonomy.Alias]) -> [String] {
    let own = aliases.filter { $0.dimension == ref.dimension && $0.bucketKey == ref.key }
      .map(\.rawValue)
    return Set(taxonomy.words(for: ref.key, in: ref.dimension) + own).sorted()
  }

  /// The other buckets that the beans carrying this one also carry, first-seen order.
  private func relatedBuckets(of carriers: [Bean], aliases: [Taxonomy.Alias]) -> [BucketRef] {
    var seen: Set<BucketRef> = [ref]
    return carriers.flatMap {
      ExploreModel.buckets(of: $0, taxonomy: taxonomy, aliases: aliases)
    }.filter { seen.insert($0).inserted }
  }

  private func section<Content: View>(
    _ title: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.sm) {
      Text(title.uppercased()).font(DS.Font.label).foregroundStyle(DS.ink2)
        .accessibilityAddTraits(.isHeader)
      content()
    }
  }
}
