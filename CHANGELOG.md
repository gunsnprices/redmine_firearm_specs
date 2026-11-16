# Changelog

## 1.0.0 (2026-11-16)

First release.

- Wiki macros `{{gun_specs(title)}}`, `{{cost_per_round(price, rounds or title)}}` and `{{caliber(text)}}`, for wiki
  pages, issues, notes, news and every other text that Redmine formats (Textile and CommonMark Markdown).
- `{{gun_specs}}` options `kind=`, `brand=`, `mpn=`, `price=` and `decimals=`; `{{cost_per_round}}` option
  `decimals=`.
- Settings: links from caliber names to their GunsNPrices price comparison pages (off by default) and the currency
  symbol (default `$`).
- Uses the [gunsnprices](https://rubygems.org/gems/gunsnprices) gem 0.1.
- Tested with Redmine 7.0.3 (Ruby 4.0) and 6.1.6 (Ruby 3.3) on SQLite; CI runs the tests on Redmine 5.1, 6.0, 6.1
  and 7.0.
