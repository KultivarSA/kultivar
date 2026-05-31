import 'package:flutter/material.dart';
import '../models/training_details.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Training technique reference library
//
// Const data shown in the technique picker and reference info sheet.
// Every technique growers actually use — with real, actionable content.
// ─────────────────────────────────────────────────────────────────────────────

class TrainingTechniqueInfo {
  final TrainingTechnique technique;
  final IconData icon;
  final String description;

  /// Stage window: when to apply this technique.
  final String whenToApply;

  /// Short yield/benefit statement.
  final String yieldImpact;

  /// A practical pro tip growers won't find in a basic tutorial.
  final String proTip;

  const TrainingTechniqueInfo({
    required this.technique,
    required this.icon,
    required this.description,
    required this.whenToApply,
    required this.yieldImpact,
    required this.proTip,
  });

  String get name => technique.label;
  int get stressLevel => technique.stressLevel;
  int get defaultRecoveryDays => technique.defaultRecoveryDays;

  String get stressLabel {
    switch (stressLevel) {
      case 1: return 'Low Stress';
      case 2: return 'Medium Stress';
      default: return 'High Stress';
    }
  }

  Color get stressColor {
    switch (stressLevel) {
      case 1: return const Color(0xFF00C896);   // green
      case 2: return const Color(0xFFFFB547);   // amber
      default: return const Color(0xFFEF4565);  // red
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reference data — 12 techniques
// ─────────────────────────────────────────────────────────────────────────────

const Map<TrainingTechnique, TrainingTechniqueInfo> kTrainingReference = {

  TrainingTechnique.topping: TrainingTechniqueInfo(
    technique: TrainingTechnique.topping,
    icon: Icons.content_cut_rounded,
    description:
        'Remove the apical (main) growing tip entirely, splitting the plant '
        'into two equal main colas. Creates a wider, bushier canopy with '
        'multiple top-level bud sites instead of one dominant main stem.',
    whenToApply: 'Veg · 4–6 nodes, before stretch',
    yieldImpact: 'Typically +20–40 % over untrained plants; '
        'most effective when combined with LST after recovery.',
    proTip:
        'Top 3–5 days before you would otherwise have done it — plants '
        'with fresh, vigorous root activity recover in 5 days vs. 10. '
        'Make a single clean cut just above the 3rd or 4th node, '
        'never crush the stem.',
  ),

  TrainingTechnique.fimming: TrainingTechniqueInfo(
    technique: TrainingTechnique.fimming,
    icon: Icons.cut_rounded,
    description:
        'Pinch or cut roughly 70–80 % of the newest growth tip without '
        'removing it entirely. The partial removal confuses the plant into '
        'pushing 3–4 new tops simultaneously instead of the usual 2 from '
        'a clean top.',
    whenToApply: 'Veg · 3–5 nodes',
    yieldImpact:
        'Produces more tops than topping but they tend to be slightly '
        'less uniform. Ideal when canopy evenness matters less than raw '
        'top count.',
    proTip:
        'FIM while the tip is still tightly curled — the younger the '
        'tissue the more tops it produces. If you accidentally get a '
        'clean top you\'ve just done a regular top, which is fine.',
  ),

  TrainingTechnique.lst: TrainingTechniqueInfo(
    technique: TrainingTechnique.lst,
    icon: Icons.redo_rounded,
    description:
        'Bend branches horizontally using soft ties, wire, or clips to '
        'expose lower bud sites to light. No cutting involved — stress '
        'is minimal and the plant continues growing throughout. '
        'Best used continuously from early veg through early flower.',
    whenToApply: 'Veg through week 3 of flower (before buds harden)',
    yieldImpact:
        'Even canopy = even light distribution = more bud sites at the '
        'same distance from the light. Growers consistently report '
        '15–25 % more usable yield vs. single-cola grows.',
    proTip:
        'Tie towards the outside of the pot, not the centre. '
        'Re-tie every 2–3 days — new growth straightens fast. '
        'Stop tying by day 21 of flower to avoid damaging hardening '
        'branches.',
  ),

  TrainingTechnique.supercropping: TrainingTechniqueInfo(
    technique: TrainingTechnique.supercropping,
    icon: Icons.compress_rounded,
    description:
        'Deliberately crush and bend a branch to collapse the inner '
        'fibres without breaking the outer skin. The plant heals by '
        'forming a strengthened knuckle and the bent branch is held '
        'horizontal, improving light penetration to lower sites.',
    whenToApply: 'Veg · late, or week 1–2 of stretch',
    yieldImpact:
        'Knuckles increase sap-flow capacity to the branch, often '
        'producing denser, heavier buds below the bend point. '
        'Useful for taming tall branches that escape the canopy.',
    proTip:
        'Squeeze and gently roll the branch between your fingers until '
        'you feel it "give" — a distinct soft point. Do NOT snap. '
        'If the stem starts to split, tape it immediately with '
        'grafting tape or a folded paper towel — it will heal fully.',
  ),

  TrainingTechnique.defoliation: TrainingTechniqueInfo(
    technique: TrainingTechnique.defoliation,
    icon: Icons.eco_rounded,
    description:
        'Strategic removal of fan leaves to improve air circulation and '
        'direct energy toward bud development. Light defoliation '
        'removes only blocking leaves; heavy defoliation (schwazzing) '
        'removes 50–70 % of foliage at specific trigger points.',
    whenToApply:
        'Veg (light, ongoing) · Day 1 of flip · Day 21 of flower',
    yieldImpact:
        'Correctly timed defoliation can add 10–20 % to final weight '
        'by redirecting energy from leaves to buds. Mistimed or '
        'over-aggressive defoliation reduces yield.',
    proTip:
        'Never defoliate more than 20 % of leaves in a single session '
        'outside of dedicated defoliation events. Always wait until '
        'the plant is fully recovered and vigorous — a stressed plant '
        'should never be defoliated.',
  ),

  TrainingTechnique.lollipopping: TrainingTechniqueInfo(
    technique: TrainingTechnique.lollipopping,
    icon: Icons.remove_circle_outline_rounded,
    description:
        'Remove all growth from the bottom third to half of the plant — '
        'leaves, small branches, and bud sites — leaving a clean stem '
        'below and a full canopy above. The plant stops wasting energy '
        'on "popcorn" buds that will never develop properly.',
    whenToApply: 'Flip day (day 0) to day 7 of flower',
    yieldImpact:
        'Concentrates energy into top-canopy buds. Paired with '
        'defoliation on day 21, most growers see 10–15 % larger top '
        'colas and significantly better airflow.',
    proTip:
        'Use sharp, sterile scissors. Remove entire branches cleanly '
        'at the node — leaving stubs creates infection points. '
        'Do this all in one session rather than spreading it over days.',
  ),

  TrainingTechnique.scrog: TrainingTechniqueInfo(
    technique: TrainingTechnique.scrog,
    icon: Icons.grid_on_rounded,
    description:
        'Screen of Green — weave and tuck growing branches through a '
        'horizontal screen (10×10 cm squares) mounted 30–40 cm above '
        'the pot. Fill 60–70 % of the screen before flipping to flower, '
        'then stop tucking and let buds grow vertically.',
    whenToApply: 'Veg · once 20 cm of stem is available',
    yieldImpact:
        'Maximum light efficiency — every bud site sits at the same '
        'distance from the light. The single most effective technique '
        'for maximising yield-per-watt in a fixed space.',
    proTip:
        'Fill 60–70 % of the screen in veg, not 100 %. The remaining '
        '30–40 % fills during the first 2 weeks of stretch. '
        'Stop tucking at day 14 of flower — tucking after this point '
        'damages developing bud sites.',
  ),

  TrainingTechnique.mainlining: TrainingTechniqueInfo(
    technique: TrainingTechnique.mainlining,
    icon: Icons.device_hub_rounded,
    description:
        'A structured manifold technique — top the plant at node 3, '
        'remove everything below the two remaining branches, then LST '
        'both branches to 90°. Top each branch again at node 3 to '
        'create 4 equal mains. Repeat for 8 or 16 main colas.',
    whenToApply: 'Veg · from node 3, requires 6–8 extra veg weeks',
    yieldImpact:
        'Produces 8 or 16 perfectly uniform, heavy colas from a single '
        'plant. Yield-per-plant is very high but veg time is '
        'significantly longer.',
    proTip:
        'Each topping requires full recovery before the next one. '
        'Patience here pays off — rushing a manifold gives uneven '
        'mains that negate the benefit. Use 8 mains for most grows; '
        '16 only with very long veg.',
  ),

  TrainingTechnique.pinching: TrainingTechniqueInfo(
    technique: TrainingTechnique.pinching,
    icon: Icons.pinch_rounded,
    description:
        'Gently squeeze the top 5–10 mm of the growing tip between '
        'fingernails or tweezers, slightly bruising the tissue without '
        'removing it. This briefly interrupts apical dominance and '
        'encourages lateral growth with much less recovery time than '
        'topping.',
    whenToApply: 'Veg · early, before 4 nodes',
    yieldImpact:
        'Subtle — improves branching vs. untrained but less dramatic '
        'than topping. Best used when recovery time is a constraint '
        'or as a gentler first training on sensitive genetics.',
    proTip:
        'Pinching works best on very young plants (2–3 nodes) when the '
        'tip tissue is still soft. On older, tougher stems it has '
        'little effect — top instead.',
  ),

  TrainingTechnique.schwazzing: TrainingTechniqueInfo(
    technique: TrainingTechnique.schwazzing,
    icon: Icons.layers_clear_rounded,
    description:
        'An aggressive, scheduled defoliation protocol: remove 50–70 % '
        'of all leaves on day 1 of flower flip and again on day 21. '
        'Based on the "Three a Light" method, it forces the plant to '
        'redirect all energy to bud production rather than leaf '
        'maintenance.',
    whenToApply: 'Day 1 of flower · Day 21 of flower only',
    yieldImpact:
        'Proponents report 20–40 % heavier harvests in optimised '
        'environments. Less effective under lower-intensity lighting '
        'where leaves are needed for photosynthesis.',
    proTip:
        'Only schwazz if: your lights are ≥ 600 µmol/m²/s PPFD, the '
        'plant is fully healthy, and you have a strong nutrient program '
        'to support the accelerated growth. Under HPS or lower-power '
        'LED, standard defoliation outperforms schwazzing.',
  ),

  TrainingTechnique.sog: TrainingTechniqueInfo(
    technique: TrainingTechnique.sog,
    icon: Icons.apps_rounded,
    description:
        'Sea of Green — flip multiple small plants to flower early '
        '(at 20–30 cm) to fill the canopy quickly with many single-cola '
        'plants rather than a few large trained ones. Minimises veg time '
        'and maximises turns per year.',
    whenToApply: 'Flip at 20–30 cm height in veg',
    yieldImpact:
        'Lower yield per plant but more harvests per year. Best for '
        'clonal grows where genetics are consistent and space is fully '
        'utilised.',
    proTip:
        'SOG works best with uniform clones — seed plants vary too much '
        'in height and timing. Space plants at 1 per 30×30 cm. '
        'More than 4 plants/m² in most jurisdictions changes your legal '
        'classification — know your local rules.',
  ),

  TrainingTechnique.other: TrainingTechniqueInfo(
    technique: TrainingTechnique.other,
    icon: Icons.more_horiz_rounded,
    description:
        'Any technique not covered by the list above — STS reversal, '
        'leaf tucking, stake training, canopy netting, or any '
        'experimental method.',
    whenToApply: 'Varies by technique',
    yieldImpact: 'Depends on specific technique applied.',
    proTip:
        'Add a note describing the exact method so you can reference it '
        'in future grows and compare results.',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// Common target sites — shown as quick-tap chips in the log sheet.
// Filtered contextually per technique.
// ─────────────────────────────────────────────────────────────────────────────

const kCommonTargetSites = [
  'Main cola',
  'Node 3',
  'Node 4',
  'Node 5',
  'Node 6',
  'All branches',
  'Lower third',
  'Side branches',
  'Canopy',
];

/// Target sites relevant to a specific technique.
List<String> targetSitesFor(TrainingTechnique t) {
  switch (t) {
    case TrainingTechnique.topping:
    case TrainingTechnique.fimming:
      return ['Node 3', 'Node 4', 'Node 5', 'Node 6', 'Main cola'];
    case TrainingTechnique.supercropping:
      return ['Main cola', 'Side branches', 'Canopy'];
    case TrainingTechnique.lst:
      return ['Main cola', 'Side branches', 'All branches', 'Canopy'];
    case TrainingTechnique.defoliation:
    case TrainingTechnique.schwazzing:
      return ['All branches', 'Lower third', 'Canopy', 'Side branches'];
    case TrainingTechnique.lollipopping:
      return ['Lower third', 'All branches'];
    case TrainingTechnique.mainlining:
      return ['Node 3', 'Node 4', 'Main cola'];
    case TrainingTechnique.pinching:
      return ['Main cola', 'Node 3', 'Node 4'];
    default:
      return kCommonTargetSites;
  }
}
