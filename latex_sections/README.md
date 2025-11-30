# LaTeX Manuscript: Q2d with Projection Function and Dead Time Compensation

Complete LaTeX source for the publication on Q2d Q-learning controller with projection function and dead time compensation.

## File Structure

```
latex_sections/
├── 00_main.tex                  # Master document (compile this)
├── 01_abstract.tex              # Abstract (0.3 pages)
├── 02_introduction.tex          # Introduction (1.5 pages)
├── 03_problem_statement.tex     # Problem Statement (0.8 pages)
├── 04_q2d_projection.tex        # Q2d with Projection (2.2 pages)
├── 05_deadtime_compensation.tex # Dead Time Compensation (1.8 pages)
├── 06_validation_results.tex    # Validation & Results (2.5 pages)
├── 07_discussion.tex            # Discussion (1.2 pages)
├── 08_conclusions.tex           # Conclusions (0.7 pages)
├── 09_acknowledgments.tex       # Acknowledgments
├── references.bib               # Bibliography (BibTeX format)
└── README.md                    # This file
```

**Total**: ~10.0 pages (excluding references)

## Compilation Instructions

### Standard LaTeX Compilation

```bash
cd "/mnt/c/Users/Kuba_PC/Mój dysk/MATLAB/Doktorat/Q_learning_2026/latex_sections"

# Full compilation sequence
pdflatex 00_main.tex
bibtex 00_main
pdflatex 00_main.tex
pdflatex 00_main.tex
```

### Alternative: Using latexmk (recommended)

```bash
latexmk -pdf -interaction=nonstopmode 00_main.tex
```

### Clean Build Artifacts

```bash
latexmk -c  # Clean auxiliary files
latexmk -C  # Clean all generated files including PDF
```

## Required LaTeX Packages

The manuscript uses standard IEEE Transactions template packages:

- `IEEEtran` - IEEE Transactions document class
- `amsmath`, `amssymb`, `amsfonts` - Mathematical symbols
- `algorithm`, `algorithmic` - Algorithm formatting
- `graphicx` - Figure inclusion
- `multirow` - Complex tables
- `cite` - Citation management
- `hyperref` - Hyperlinks in PDF

All packages are standard in modern LaTeX distributions (TeX Live, MiKTeX).

## Figures Directory

**IMPORTANT**: Before compiling, create a `figures/` subdirectory:

```bash
mkdir -p figures
```

Place all generated figure files in this directory with exact names referenced in the .tex files:

### Required Figures (7 total)

1. `q_goal_convergence_T0_4.pdf` - Q(goal,goal) convergence (3 subplots)
2. `step_response_T0_4.pdf` - Step response comparison (PI vs Q-before vs Q-after)
3. `training_progression_T0_0.pdf` - Training progression (4 epochs × 3 subplots)
4. `performance_matrix.pdf` - Performance metrics bar chart matrix
5. `disturbance_rejection_T0_2.pdf` - Load disturbance rejection time series
6. (Optional) `q_matrix_visualization.pdf` - Q-matrix heatmap before/after
7. (Optional) `compensation_strategy_comparison.pdf` - Line plot of strategies

Generate these figures using MATLAB scripts after running experiments.

## Customization Points

### Title

Edit line 22 in `00_main.tex`:
```latex
\title{Your Custom Title Here}
```

### Authors

Edit lines 24-28 in `00_main.tex` for author list and affiliations.

### Funding

Edit `09_acknowledgments.tex` for grant numbers and acknowledgments.

### Target Journal

Current template: IEEE Transactions format

To adapt for other journals:
- **Control Engineering Practice**: Change documentclass to `\documentclass[review]{elsarticle}`
- **Journal of Process Control**: Similar Elsevier format
- **Automatica**: Use Elsevier template
- **ISA Transactions**: Use Elsevier template

## Section-by-Section Breakdown

| Section | File | Content | Pages |
|---------|------|---------|-------|
| Abstract | 01_abstract.tex | Problem, solution, results, significance | 0.3 |
| 1. Introduction | 02_introduction.tex | Industrial motivation, Q-learning background, contributions | 1.5 |
| 2. Problem Statement | 03_problem_statement.tex | Q-learning basics, control objective, dead time challenge | 0.8 |
| 3. Q2d with Projection | 04_q2d_projection.tex | State merging, projection derivation, generation algorithm | 2.2 |
| 4. Dead Time Compensation | 05_deadtime_compensation.tex | Delayed credit assignment, sparse reward, continuous learning | 1.8 |
| 5. Validation | 06_validation_results.tex | Experimental setup, convergence results, performance metrics | 2.5 |
| 6. Discussion | 07_discussion.tex | Projection analysis, dead time effectiveness, practical guidelines | 1.2 |
| 7. Conclusions | 08_conclusions.tex | Summary of contributions, future work | 0.7 |

## Tables Included

The manuscript includes 4 main tables (placeholders with example data):

- **Table 1** (Section 5.2): Q(goal,goal) convergence by compensation strategy
- **Table 2** (Section 5.3): Performance metrics vs. PI baseline (T0=0)
- **Table 3** (Section 5.4): IAE improvement percentage across models and dead times
- **Table 4** (Section 5.4): Effect of compensation strategy on IAE improvement

Replace example data with actual experimental results.

## Equations Numbering

Key equations are numbered and cross-referenced:
- Eq. (1): Target trajectory
- Eq. (2): Merged state definition
- Eq. (3): Projection function
- Eq. (4): Q-learning update rule
- Eq. (5): Control law with projection
- ... (continuing through all sections)

## Citations Management

### Adding New References

1. Open `references.bib`
2. Add entry in appropriate category (see comments in file)
3. Use consistent formatting (author, title, journal, year, volume, pages, DOI)
4. Cite in .tex files using `\cite{key}`

### Citation Style

IEEE Transactions style: `[1], [2], [3]` etc.

Format: Author et al., "Title," Journal, vol. X, no. Y, pp. ZZZ, Year.

### Placeholder Citations

Some citations marked with "XXXXXXX" or "to be added" - replace with actual references from literature review.

## Proofreading Checklist

Before submission:

- [ ] All figures generated and placed in `figures/` directory
- [ ] All tables updated with real experimental data
- [ ] All citations have corresponding entries in `references.bib`
- [ ] All `XXXXXXX` placeholders replaced with actual values
- [ ] Author names and affiliations verified
- [ ] Grant numbers and acknowledgments updated
- [ ] Equations cross-referenced correctly
- [ ] Section/figure/table cross-references working
- [ ] Spell-check completed
- [ ] Formatting consistent throughout
- [ ] Page count within journal limits (~10 pages)
- [ ] All notation defined on first use
- [ ] Abstract within word limit (200-250 words)

## Known Issues / TODOs

1. **Experimental Data**: All tables contain placeholder values - replace with actual results
2. **Figures**: Need to generate all 7 figures from MATLAB experiments
3. **References**: ~15 citations included, need ~25-30 more from literature review
4. **Biography Photos**: If required by journal, add author photos
5. **Supplementary Material**: Consider creating supplementary document with:
   - Complete algorithm pseudocode
   - Additional experimental scenarios
   - MATLAB code snippets
   - Extended parameter sensitivity analysis

## Writing Style

Based on ASC submission and Q2d methodology:

- **Tone**: Formal academic, objective
- **Tense**: Present for general facts, past for experiments
- **Person**: Third person ("the controller", "we propose")
- **Terminology**: Consistent (Q2d, dead time, projection function, etc.)
- **Abbreviations**: Defined on first use

## Contact

**Corresponding Author**: Prof. Jacek Czeczot (jacek.czeczot@polsl.pl)

**Co-authors**:
- Jakub Musiał (jakub.musial@polsl.pl)
- Krzysztof Stebel (krzysztof.stebel@polsl.pl)

---

**Document Status**: Complete LaTeX structure v1.0
**Created**: 2025-11-30
**Last Updated**: 2025-11-30
**Ready for**: Data insertion and figure generation
