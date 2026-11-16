# Firearm Specs for Redmine

[![CI](https://github.com/gunsnprices/redmine_firearm_specs/actions/workflows/ci.yml/badge.svg)](https://github.com/gunsnprices/redmine_firearm_specs/actions/workflows/ci.yml)

Firearm Specs (`redmine_firearm_specs`) is a Redmine plugin for teams that write about firearms and ammunition in
Redmine: gun shops, ranges, importers, catalog and e-commerce teams. It adds three wiki macros that read the caliber,
model, magazine capacity, barrel length and rounds per box from a product title, and that compute the cost per round
of ammunition.

```
{{gun_specs(Glock 19 Gen 5 MOS 9mm 4.02in 15rd Pistol)}}
```

shows this table:

| Type          | Firearm            |
|---------------|--------------------|
| Brand         | Glock              |
| Model         | Glock 19 Gen 5 MOS |
| Caliber       | 9×19mm Parabellum  |
| Capacity      | 15 rounds          |
| Barrel length | 4.02 in            |

```
{{cost_per_round(18.99, Federal 9mm 115gr 50rd)}}   → $0.38 per round
{{caliber(300 BLK)}}                                → .300 AAC Blackout
```

The macros work everywhere Redmine formats text: wiki pages, issue descriptions and notes, news, forum messages and
project descriptions, with Textile and with CommonMark Markdown.

The plugin uses the open source title parser of [GunsNPrices](https://gunsnprices.com), a price comparison site for
US gun and ammo stores: the [gunsnprices](https://rubygems.org/gems/gunsnprices) Ruby gem. The parser knows 293
calibers with the spellings retailers use ("9MM LUGER", "5.56 NATO", "12GA", "300 BLK") and the models of 50 brands.
It runs inside Redmine. The plugin makes no HTTP requests, has no tracking and adds no database tables.

- Source and issues: https://github.com/gunsnprices/redmine_firearm_specs
- Parser gem: https://github.com/gunsnprices/gunsnprices-ruby
- The same parser for other languages and platforms: https://gunsnprices.com/developers

## Requirements

- Redmine 5.1 or later. Tested with Redmine 7.0, 6.1, 6.0 and 5.1 (5.1 is no longer maintained by the Redmine
  team).
- A Ruby version that your Redmine version supports. The gem needs Ruby 3.0 or later.
- The [gunsnprices](https://rubygems.org/gems/gunsnprices) gem 0.1, installed by Bundler in step 2 below. It is pure
  Ruby with no dependencies.
- Any database that Redmine supports. The plugin stores only its two settings, in Redmine's `settings` table.

## Installation

1. Put the plugin in the `plugins` directory of Redmine. The directory must be named `redmine_firearm_specs`.

   ```bash
   cd /path/to/redmine/plugins
   git clone --branch v1.0.0 https://github.com/gunsnprices/redmine_firearm_specs.git
   ```

   Or download the archive of a release from https://github.com/gunsnprices/redmine_firearm_specs/releases, extract
   it to `plugins/` and rename the directory to `redmine_firearm_specs`.

2. Install the gem. In the Redmine directory, run Bundler the same way as when you installed Redmine, for example:

   ```bash
   cd /path/to/redmine
   bundle install
   ```

   Redmine's `Gemfile` reads the plugin's `Gemfile`, which adds `gem "gunsnprices", "~> 0.1"`.

3. Restart Redmine (for example `touch tmp/restart.txt` with Passenger, or restart Puma or the application server).

The plugin has no database migrations, so `rake redmine:plugins:migrate` is not needed (running it does no harm).

Open **Administration → Plugins**: the list shows **Firearm Specs 1.0.0**. Its **Configure** link opens the
settings.

To update, replace the directory with the new version, run `bundle install` and restart Redmine.

To uninstall, delete `plugins/redmine_firearm_specs`, run `bundle install` and restart Redmine. Pages that use the
macros then show the macro text as written. The settings stay in the `settings` table under the name
`plugin_redmine_firearm_specs`; you can delete that row.

## Macros

Write the arguments in parentheses, without quotes. Titles may contain commas, parentheses and quotes.

### {{gun_specs}}

```
{{gun_specs(title)}}
{{gun_specs(title, kind=firearm|ammo, brand=..., mpn=..., price=..., decimals=0..4)}}
```

Shows a table of the specs found in a product title. Rows that the title does not have are left out:

| Row            | Shown for                     | Example                       |
|----------------|-------------------------------|-------------------------------|
| Type           | always                        | Firearm, Ammunition           |
| Brand          | firearms with a known model, or the `brand=` option | Glock   |
| Model          | firearms of the 50 brands      | Glock 19 Gen 5 MOS            |
| Caliber        | all calibers in the title      | .357 Mag, .38 S&W Special     |
| Capacity       | firearms; for "15+1" it is 15  | 15 rounds                     |
| Barrel length  | firearms, in inches            | 4.02 in                       |
| Rounds per box | ammunition                     | 1,000                         |
| Price          | with `price=`                  | $18.99                        |
| Cost per round | ammunition with `price=`       | $0.38                         |

Options, all optional, go after the title, each after a comma:

- `kind=firearm` or `kind=ammo`: skip the guess. Without it, the type is guessed from the title: a bullet weight
  ("115gr"), a box count ("50/Box", "Box of 50") or the word "ammo" mean ammunition. Short titles such as
  "Magtech 9mm 50rd" need `kind=ammo`.
- `brand=`: the brand, for titles that do not name it.
- `mpn=`: the manufacturer part number. It identifies Glock models when the title does not.
- `price=`: the price of the item, such as `18.99`, `$18.99` or `1,299.00`. Adds the Price row and, for ammunition,
  the Cost per round row.
- `decimals=`: decimal places of the cost per round, 0 to 4 (default 2).

```
{{gun_specs(Federal American Eagle 9mm Luger 115gr FMJ, 50/Box, price=18.99)}}
{{gun_specs(Magtech 9mm 1000rd, kind=ammo, price=$299.99, decimals=3)}}
{{gun_specs(GLOCK 9MM PISTOL 15RD, brand=Glock, mpn=UA4350201)}}
```

If nothing is found in the title, the macro shows "No firearm or ammunition specs found in: ..." instead of a table.

### {{cost_per_round}}

```
{{cost_per_round(price, rounds)}}
{{cost_per_round(price, ammunition title)}}
{{cost_per_round(price, rounds or title, decimals=0..4)}}
```

Shows the price of one round, such as "$0.38 per round", rounded half up to 2 decimal places (or `decimals=`). The
second argument is the number of rounds (`50`, `1,000`) or an ammunition title that contains it ("Box of 20",
"50/Box", "1,000 Rounds", "20rds"). Hovering over the result shows the price and the round count it was computed
from.

```
{{cost_per_round(18.99, 50)}}                                   → $0.38 per round
{{cost_per_round(18.99, Federal 9mm 115gr FMJ, 50/Box)}}        → $0.38 per round
{{cost_per_round($1,299.00, 1,000, decimals=3)}}                → $1.299 per round
```

In the price, a comma followed by 3 digits is a thousands separator; "18,99" is not read as a price.

### {{caliber}}

```
{{caliber(text)}}
```

Shows the standard name of a caliber. The text can be a caliber in any common spelling ("9MM LUGER", "308 WIN
(7.62X51 NATO)", "12ga", "300 BLK") or a title that contains one ("Hornady Critical Defense 9mm Luger 115gr FTX
25rd"; the first caliber is used).

```
{{caliber(9MM LUGER)}}   → 9×19mm Parabellum
{{caliber(12ga)}}        → 12 Gauge
{{caliber(300 BLK)}}     → .300 AAC Blackout
```

Text without a known caliber is shown as written, with the tooltip "Unknown caliber".

### Escaping, errors and styling

- All output is escaped: titles, options, names from the parser data and the currency symbol are shown as text and
  are never read as HTML. `{{caliber(<b>x</b>)}}` shows `<b>x</b>`.
- Invalid arguments (a missing title, a price that is not a number, an unknown `kind=`) show Redmine's red "Error
  executing the ... macro" box with the reason.
- To show a macro without running it, put `!` before it: `!{{caliber(9mm)}}`.
- Redmine lists the macros with a short description when a page contains `{{macro_list}}`.
- The output has CSS classes for themes: `table.firearm-specs`, `span.firearm-specs-empty`,
  `span.firearm-specs-cost-per-round`, `.firearm-specs-caliber` (a `span`, or an `a` when links are on) and
  `.firearm-specs-unknown`. Without a theme, the table looks like other wiki tables.

## Settings

**Administration → Plugins → Firearm Specs → Configure**

| Setting                      | Default | Description |
|------------------------------|---------|-------------|
| Link calibers to GunsNPrices | off     | Caliber names in `{{gun_specs}}` and `{{caliber}}` become links to their price comparison pages on gunsnprices.com, such as https://gunsnprices.com/ammo/handgun-ammo/9-19mm-parabellum. Calibers without such a page stay plain text. |
| Currency symbol              | `$`     | Shown before prices and costs per round, up to 5 characters. Leave it empty for none. Numbers always use a dot as the decimal separator and commas between thousands. |

Settings apply to all pages at once, the next time a page is shown.

## Accuracy and limits

The parser is the one GunsNPrices uses for its catalog. Measured on 63,755 listings from 40+ US stores (October
2026) against the attributes stored on the site, the values it finds are right in 97.8% of cases for the caliber of
a firearm, 94.9% for the caliber of ammunition, 95.6% for the magazine capacity, 94.4% for the barrel length and
96.6% for the rounds per box. Many titles do not contain the caliber or the barrel length; then the row is left out.
Details are in the [gem README](https://github.com/gunsnprices/gunsnprices-ruby#accuracy).

Titles in English from US retailers work best. Models are known for 50 brands; other brands still get calibers and
numbers. Magazines, parts and accessories get calibers and numbers but no model.

The parser reads its data and compiles its rules on the first call in each Redmine process, which takes about a
quarter of a second; after that a macro takes about half a millisecond.

## Development

The tests run with Redmine's plugin test task. With the plugin in `plugins/redmine_firearm_specs` of a Redmine
checkout whose `config/database.yml` has a `test` database:

```bash
bundle install
RAILS_ENV=test bundle exec rake db:create db:migrate
RAILS_ENV=test bundle exec rake redmine:plugins:test NAME=redmine_firearm_specs
```

`test/unit` has the argument parsing and the macros rendered through Redmine's wiki formatting (Textile and
CommonMark, escaping, errors, settings), `test/functional` the settings page, and `test/integration` a wiki page, an
issue with a note and a news item saved and loaded through Redmine. GitHub Actions runs them on Redmine 5.1, 6.0, 6.1
and 7.0 with the oldest and newest Ruby that each supports (`.github/workflows/ci.yml`).

## License

The plugin is licensed under the [MIT License](LICENSE). MIT is compatible with the GNU GPL v2 under which Redmine is
distributed, so the plugin can be loaded into Redmine and distributed with it.

The gunsnprices gem is not part of this repository; Bundler installs it from RubyGems.org. Its code is under the MIT
License, and its data (the caliber list and the model dictionaries, which give the names and caliber links in the
plugin's output) is by GunsNPrices (gunsnprices.com) under [CC BY 4.0](LICENSE-DATA).

Questions and corrections: open an issue on GitHub or write to app@gunsnprices.com.
