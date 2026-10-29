Paired wall-time reduction: positive is faster. All warmups excluded.

| Target | Workload | Operation | Candidate median % | Control median % |
|---|---|---|---:|---:|
| native | tiny (0/1/15/16/17 cross product) | seal | 45.29 | 0.69 |
| native | tiny (0/1/15/16/17 cross product) | open | 40.04 | -0.06 |
| native | records (64 B to 16 KiB) | seal | 22.60 | 0.43 |
| native | records (64 B to 16 KiB) | open | 15.86 | -0.15 |
| native | full-block power/batch boundaries | seal | 17.42 | 0.31 |
| native | full-block power/batch boundaries | open | 11.79 | -0.15 |
| native | 1 MiB | seal | 0.54 | -0.44 |
| native | 1 MiB | open | -0.05 | -0.36 |
| x86_64 | tiny (0/1/15/16/17 cross product) | seal | 43.30 | 0.07 |
| x86_64 | tiny (0/1/15/16/17 cross product) | open | 39.98 | 0.23 |
| x86_64 | records (64 B to 16 KiB) | seal | 9.22 | 0.30 |
| x86_64 | records (64 B to 16 KiB) | open | 4.32 | 0.01 |
| x86_64 | full-block power/batch boundaries | seal | 5.74 | -0.00 |
| x86_64 | full-block power/batch boundaries | open | 4.38 | 0.01 |
| x86_64 | 1 MiB | seal | 0.00 | 0.07 |
| x86_64 | 1 MiB | open | -0.21 | 0.05 |

Large cases and aggregate regressions worse than 3% (all cases in case-summary.csv; paired ratios across three seeds, both module layouts):
('native', 0, 1048576, 'open'): median 0.07%, seed/layout range -0.33..1.18%, control -0.47%
('native', 0, 1048576, 'seal'): median 0.67%, seed/layout range -0.48..2.38%, control -0.37%
('native', 1048576, 0, 'open'): median -0.62%, seed/layout range -2.24..0.31%, control -0.82%
('native', 1048576, 0, 'seal'): median 0.67%, seed/layout range -1.96..1.53%, control 0.29%
('native', 1048576, 17, 'open'): median -0.05%, seed/layout range -0.88..0.70%, control 0.73%
('native', 1048576, 17, 'seal'): median 0.10%, seed/layout range -1.86..1.90%, control 0.60%
('native', 1048576, 1048576, 'open'): median 0.01%, seed/layout range -0.93..0.41%, control 0.46%
('native', 1048576, 1048576, 'seal'): median 0.47%, seed/layout range -2.02..1.58%, control -2.96%
('x86_64', 0, 1048576, 'open'): median -0.08%, seed/layout range -0.80..0.42%, control -0.46%
('x86_64', 0, 1048576, 'seal'): median -0.12%, seed/layout range -0.51..0.88%, control -0.24%
('x86_64', 1048576, 0, 'open'): median -0.25%, seed/layout range -1.61..0.86%, control 0.58%
('x86_64', 1048576, 0, 'seal'): median 0.12%, seed/layout range -0.19..0.59%, control 0.05%
('x86_64', 1048576, 17, 'open'): median -0.29%, seed/layout range -1.10..-0.10%, control 0.01%
('x86_64', 1048576, 17, 'seal'): median 0.28%, seed/layout range -1.07..0.93%, control 0.07%
('x86_64', 1048576, 1048576, 'open'): median -0.22%, seed/layout range -0.68..0.08%, control 0.20%
('x86_64', 1048576, 1048576, 'seal'): median -0.14%, seed/layout range -1.21..0.58%, control 0.26%

Individual candidate pair reduction p05/p50/p95, and baseline-v-baseline control:
native candidate: n=7476, p05=0.29, median=21.62, p95=49.85
native control: n=3738, p05=-4.30, median=0.11, p95=3.52
x86_64 candidate: n=7476, p05=-0.56, median=10.09, p95=49.14
x86_64 control: n=3738, p05=-2.04, median=0.07, p95=2.04
