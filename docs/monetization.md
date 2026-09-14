# Monetization — ads, memberships, and the bill that comes first

**Status:** scoped 2026-09-14, nothing decided. This doc exists so the shape
and the order of operations are known before anything gets built. The backlog
epic is **E18**, and its first item is the go/no-go.

## Why this doc exists

Andy, 2026-09-14: *"If I wanna monetize StatSide through ads and memberships,
what do I need to do?"*

The short answer is that the engineering is the small half. StoreKit is a
week; the paywall is a screen. What monetization actually does is convert two
things the project has been carrying quietly into things that have to be
answered out loud:

1. **The app runs on a feed it has no licence to.** `ROADMAP.md` has said
   since day one that monetization "forces the data-licensing question," and
   open question #6 in `BACKLOG.md` has option (b), a paid provider, filed
   as *"only sensible if the app ever charges."* That sentence is the whole
   doc. Charging money changes the posture from a tolerated hobby to
   commercial use of somebody else's data and somebody else's trademarks.
2. **Ads are the thing the product was sold against.** `README.md`'s first
   paragraph, the App Store description, and the CLAUDE.md target-user
   sentence all describe a fan "tired of ad-stuffed everything-apps." A
   banner does not break the build. It breaks the pitch.

Memberships are a good fit and mostly a build problem. Ads are a cheap
build and an expensive product decision. They are not the same size of
question and this doc does not pretend they are.

## The gate: what StatSide is allowed to sell

Nothing below matters until this closes, because it sets the cost floor that
every revenue number has to clear.

**The data.** Every score in the app comes from ESPN's unofficial site API —
undocumented, unlicensed, revocable without notice. 1.0 shipped on it by
taking the risk, not by resolving it (E6's own status line says so). Free
and personal is one risk posture. Paid, advertised, and generating revenue
is another, and it is the version where a cease-and-desist stops being
theoretical.

**The marks.** Team and conference logos come off ESPN's CDN and are
university and league trademarks, rendered in full colour because the colour
budget's first exception exists specifically for them. Grayscaling them is
not an escape — it is the same trademark. Open question #6 already notes
that switching to CFBD does not change this, because CFBD's logo URLs point
at ESPN's CDN too.

**What it actually costs — published rates, gathered 2026-09-14.** The
enterprise reputation of this category is misleading. Sportradar is the name
everyone hears and it is the one tier StatSide never needs.

| Provider | Covers | Published rate | Notes |
|---|---|---|---|
| **CollegeFootballData.com** | College football (and CBB via CBBD) | **$10/mo** (Patreon Tier 3, 75k calls, GraphQL with realtime subscriptions) | **Commercial use is permitted**, and crediting CFBD as the source is strongly encouraged. Already implemented — `CFBDClient` conforms to `ScoresProviding` today |
| **Goalserve — US Sports Package** | **NFL, NBA, MLB, NHL** | **$400/mo**, or $3,100/yr (~$258/mo) | Fixtures, live scores, in-game player stats, injuries, H2H, history since 2010. Licence is by application, reviewed case by case against your stated use |
| Goalserve — NFL/NCAA live | NFL + NCAA football | $300/mo, $1,500/yr | Narrower, and overlaps what CFBD already covers for $10 |
| **API-Sports** | American football, basketball, hockey, baseball + 5 more | **$29–39/mo** (Ultra 75k/day, Mega 150k/day) | Cheapest by an order of magnitude. Latency, coverage depth and licence terms all unverified |
| SportsDataIO — Discovery Lab | Most US sports | $99–149/mo | **Explicitly not licensed for commercial redistribution**, and next-day delayed. Wrong product, and the trap to avoid |
| SportsDataIO — production | Most US sports | Quote only; secondhand reports of **$300–500/mo per sport** | The real licence. Needs a sales conversation |
| Sportradar | Everything, officially licensed | **$1,250/mo floor**, reports of $10,000+ | Enterprise B2B with no public rate card. Not this app's tier |

**So the realistic stack for StatSide is two vendors, not one:**

- **CFBD at $10/mo** for college football, which is already built and already
  commercially licensed.
- **Goalserve's US Sports Package at $400/mo**, or $258/mo paid annually, for
  the NFL, NBA and NHL. MLB rides along, which is E17 answered for free.

That's roughly **$270–410/month** for a licensed four-league app, and about
**$40–50/month** if API-Sports turns out to be good enough for the three pro
leagues. The range worth planning against is **$50 to $450 a month**, not the
thousands the Sportradar number implies.

*Every figure above is a published list price read on 2026-09-14, not a quote
anyone gave us. Goalserve's licence is granted by application, so the price
and the permission are two separate answers.*

**The logos are still unsolved, by any of them.** None of these vendors sells
the right to display Michigan's block M. StatSide renders team marks in full
colour because the colour budget's first exception exists for exactly that,
and a data licence does not carry a trademark licence. This stays a risk
accepted rather than a problem paid away, and it should be written down as an
accepted risk rather than left unmentioned.

**Latency is an acceptance criterion, not a footnote.** The product promise is
time-to-score. A feed that is 60 seconds behind ESPN makes StatSide the slow
app, which is the one thing it cannot be. Any provider swap gets tested
against a live Saturday with ESPN open beside it before it ships.

### The arithmetic that makes it concrete

Apple takes 30%, or **15%** under the Small Business Program (under $1M/yr,
and enrolment is not automatic). At 15%, a $19.99 annual membership nets
**$16.99/yr**, which is **$1.42/month per subscriber**.

So the monthly feed bill divided by $1.42 is roughly the number of annual
subscribers required to break even **on data alone**, before a dollar of
profit, before the APNs service, before the domain:

| Feed stack | Monthly | Annual subscribers to break even |
|---|---|---|
| API-Sports + CFBD | ~$50 | **~35** |
| Goalserve US annual + CFBD | ~$270 | **~190** |
| Goalserve US monthly + CFBD | ~$410 | **~290** |
| SportsDataIO production (mid estimate) | ~$1,200 | ~845 |

**35 to 290 subscribers.** That is a number a single good season can produce,
which is the finding that moves this from "probably not worth it" to "worth
pricing properly."

Against that, the honest second question: how many installs does StatSide
have today? The app collects no analytics by design, so the only place that
number lives is App Store Connect, and Andy is the only person who can read
it. A 3–5% paid conversion rate is a healthy consumer app. Work backwards.

## Ads

### What they'd cost the product

- **The positioning.** The README, the store description and the whole
  target-user premise sell an app that isn't ad-stuffed. Shipping ads makes
  StatSide the category it was built against, and reviewers will say so in
  the words the listing used.
- **The zero-dependency rule.** Every ad network is an SDK, and it is the
  heaviest kind of SDK — one that collects data, ships its own networking,
  and updates on its own schedule. `README.md` lists "zero third-party
  dependencies, by decision" as a requirement. AdMob would be the first one.
- **The privacy story, in full.** `PRIVACY.md` currently opens **"Nothing."**
  and says, in as many words, "no advertising" and "no third-party SDKs of
  any kind." The App Store nutrition label reads **Data Not Collected**. An
  ad SDK flips all of it: a rewritten policy, a new label (Identifiers,
  Usage Data, probably *Used to Track You*), an **ATT prompt** before any
  IDFA access, the SDK's **privacy manifest and signature** carried into
  every build, and SKAdNetwork ids in the Info.plist.
- **The design system.** A banner is full-colour third-party artwork nobody
  here controls — a fourth exception to a three-exception colour budget, and
  the only one that changes every refresh. The density target is
  FotMob-level; a 50pt banner is roughly a game row and a half of the slate.
- **Placement has no good answer.** The Saturday sort order is the product
  (principle 1), so the slate is out. Sections are complete and never
  deduplicated (principle 3), so interleaving an ad unit into a section
  breaks the one promise a section makes. What's left is below the fold on
  game detail, which is also where the fewest eyes are.
- **The 4+ rating.** StatSide is rated 4+. Ads have to match the rating,
  which rules out the highest-CPM advertiser category in all of sports —
  sportsbooks — which additionally drags in Guideline 5.3 and a 17+ rating.

### What they'd actually pay

Assumptions, clearly labelled as assumptions: a $2 banner CPM, 20 sessions a
weekend per active user, 3 impressions a session.

At **1,000 weekly actives** that is ~60,000 impressions a weekend, about
**$120 a weekend**, call it **$500 a month in football season** and
materially less the rest of the year even with basketball and hockey now
running to June. It would clear the cheap end of the feed bill and little
else, and it costs the app its entire positioning to earn — against a
membership that clears the same bill at 35 to 290 subscribers without
rewriting a word of the README.

### The version worth considering

**One direct-sold sponsorship slot, served by our own service.** A single
static card, drawn in the app's own type and mono palette, sold to one
partner at a time and served from the existing Vercel deployment as a small
JSON payload. No SDK, no IDFA, no ATT prompt, no privacy manifest, and
**"Data Not Collected" survives intact** — because it collects nothing.

It is slower money and it needs a salesperson (Andy). It is also the only
form of advertising that doesn't contradict a word of the README. If ads
happen, this is the shape.

## Memberships

This is the good half, and it fits the app's existing constraints almost
suspiciously well.

**StoreKit 2 is first-party.** It ships in the SDK, so the zero-dependency
rule survives untouched.

**No accounts required.** Entitlement comes from
`Transaction.currentEntitlements`, which is per Apple ID: it syncs across a
user's devices, restores for free, and handles lapses and refunds without a
server. "No accounts, no backend, no analytics" holds. Receipt validation on
a server is optional for an app this shape and is not worth adding one for.

**What would need building:**

- An App Store Connect subscription group, product ids, localized display
  names, and a review screenshot of the paywall.
- `SubscriptionStore` — an `@Observable` in `Stores/`, listening to
  `Transaction.updates`, exposing one `isMember` the gated sites read.
- A paywall view, in the design system, stating **what you get, the price,
  the billing period, and that it auto-renews**, with working links to the
  privacy policy and the terms. Guideline 3.1.2 rejections are almost always
  that block being missing or vague.
- **Restore Purchases**, and a Manage Subscription entry point
  (`showManageSubscriptions`). Both are required, both are one line.
- Gating checks at the feature sites, and a graceful lapsed state.

**Two things App Store Connect needs that don't exist yet:**

1. **The paid apps agreement** — banking details and tax forms (W-9), which
   have to be complete and accepted before a single IAP can be sold. Enrol
   in the Small Business Program at the same time; 15% versus 30% is the
   difference between the break-even table above and one twice as steep.
2. **A Terms of Use page.** There is a privacy policy at `statside.co/privacy`
   and a support page at `/support`; there is **no ToS anywhere**, and Apple
   requires a functional EULA link on the paywall and in the listing
   metadata. `/terms` slots in beside the other two and reuses the exact
   mechanism the 2026-09-13 decision built: markdown at the repo root,
   mirrored into `web/src/content/` under a byte-equality test that fails
   Web CI. Cheap, and the drift problem is already solved.

**One rule that isn't Apple's.** Nothing that shipped free in 1.x or 2.x
goes behind the paywall. Apple would allow it; users would not, and a
1-star run is more expensive than the subscribers it would buy. The paid
tier has to be **new**.

## So what is actually sellable

The backlog already contains the answer, and it is the one feature whose
cost scales with the number of people using it:

**Live Activities and live push (E12).** The lock-screen card for a live
game is the roadmap's own "probably the killer feature for this app." It
needs the APNs broadcast service to exist, it costs real money to run, and
the value is continuous rather than one-shot. That is textbook subscription
material: people pay for a service you keep running, not for a screen you
already shipped.

Reasonable companions, all additive:

- **Score alerts beyond the kickoff reminder** — final, close game, red
  zone. The existing 30-minute local reminder stays free; it shipped free.
- **Push-to-start**, so a followed team's card appears without opening the
  app (E12's last item).
- **The season archive** — past polls and past seasons already work through
  the core API's season axis, and "every AP poll back to 2003" reads premium
  without costing anything per user.

What stays free, permanently, and should be said out loud in the listing:
**the scores screen, the day strip, the sort order, follows, standings,
the polls, the widget and the kickoff reminder.** Paywalling the slate would
gut the funnel and invite a fresh look at the 4.2.2 rejection the app
already survived once.

## Pricing

The comparable set is FotMob (roughly $1/month, ~$10/year), theScore (free,
ad-supported), and ESPN (bundled into a much larger subscription). A
defensible first shape:

- **$2.99/month**, **$19.99/year** (the annual is where the revenue is), and
  optionally a lifetime unlock for the people who will never subscribe to
  anything.
- **No free trial in the first cut.** Offer one after the feature has
  survived a full weekend of real traffic — a trial that expires during a
  broken Saturday is a refund and a review.

## The web half

`statside.co` is a second surface with different rules. Ads there need no
SDK and carry none of the iOS compliance load, though Vercel Analytics is
already disclosed in the policy and anything more would need another
disclosure. Memberships on the web are the harder half: a StoreKit
entitlement cannot cross to a browser without an account system, and
accounts are a thing this project has deliberately never had. **Keep
membership iOS-only in the first cut.** Whatever lands here needs a
`docs/web-parity.md` row either way.

## Recommendation

1. **Apply to Goalserve and trial API-Sports.** The published rates say a
   licensed four-league app costs $50–450/month, so the gate is no longer
   "can this be afforded" but "is the cheap feed fast enough." Test latency
   against a live Saturday with ESPN open beside it.
2. **Memberships, not ads.** A subscription that pays for the live service
   is a story consistent with every word already written about this app. A
   banner is a small cheque and a rewritten identity.
3. **Ship E12 free to everybody for one weekend** before charging for it, so
   the running cost is a measurement rather than a guess.
4. **If ad money is wanted anyway, sell one sponsorship slot directly** and
   serve it ourselves. No SDK, no tracking, no label change.

## The question for Andy

Three, in order, and the first one gates the rest:

1. **$270/month for a licensed feed, or keep taking the ESPN risk?** That is
   CFBD at $10 plus Goalserve's US package paid annually, and it breaks even
   at roughly 190 annual subscribers. The logos stay an accepted risk either
   way, because no vendor sells that right.
2. **Membership only, or membership plus a direct-sold sponsorship?** Saying
   "no ad SDK, ever" out loud is worth a decisions-log row on its own.
3. **Is Live Activities the thing people pay for?** If yes, E12 stops being
   a P2 nice-to-have and becomes the product's first paid feature, which
   changes how it gets built and what "finished" means.

## Sources for the pricing table

Read 2026-09-14. List prices move, and none of these is a quote given to us.

- CollegeFootballData.com — [API access tiers](https://collegefootballdata.com/api-tiers), [terms](https://collegefootballdata.com/terms)
- Goalserve — [US Sports Package prices](https://www.goalserve.com/en/sport-data-feeds/ussports-api/prices), [NFL/NCAA prices](https://www.goalserve.com/en/sport-data-feeds/nfl-api/prices), [full package](https://www.goalserve.com/en/sport-data-feeds/full-package-api/prices)
- API-Sports — [api-sports.io](https://api-sports.io/)
- SportsDataIO — [sportsdata.io](https://sportsdata.io/), [Discovery Lab](https://discoverylab.sportsdata.io/personal-use-apis/ncaa-football)
- Sportradar rates, secondhand — [SharpAPI's provider comparison](https://sharpapi.io/compare/sports-data-apis), [LSports' 2026 cost guide](https://www.lsports.eu/blog/sports-data-cost/)
