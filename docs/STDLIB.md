# Standard library (stdlib/)

Modules, split by what they need from the compiler. Every helper is checked
by a `make` target; the backend columns below say what is verified.

| Module | Helpers | Backends | Gate |
|---|---|---|---|
| `stdlib/tiny.sa` | 36 `make` definitions: 31 public numeric helpers and 5 internal recursion helpers (`no_factor_from`, `rev_num`, `has_sq_from`, `div_floor`, `isqrt_from`) | seed-min, gen2, native | `test-stdlib`, `test-stdlib-growth` |
| `stdlib/str_util.sa` | 14 string helpers (`s_len`, `s_at`, `s_join`, `s_prefix`, `s_suffix`, `s_reverse`, `s_repeat`, `s_count`, `s_contains`, `s_eq`, `s_upper`, `s_lower`, `s_starts`, `s_ends`) | seed-min, gen2, native | `test-stdlib` |
| `stdlib/list_util.sa` | 9 list helpers (`l_len`, `l_get`, `l_sum`, `l_max`, `l_min`, `l_count`, `l_contains`, `l_reverse`, `l_range`) | seed-min, gen2, native | `test-stdlib` |
| `stdlib/file_util.sa` | 5 file helpers (`f_read`, `f_write`, `f_size`, `f_exists`, `f_lines`) | seed-min, gen2, native | `test-stdlib` |
| `stdlib/num_util.sa` | 17 untyped numeric helpers (`nu_trunc`, `nu_floor`, `nu_ceil`, `nu_round`, `nu_frac`, `nu_min`, `nu_max`, `nu_mod_pos`, `nu_int_div`, `nu_wrap`, `nu_map_range`, `nu_avg`, `nu_median3`, `nu_pi`, `nu_deg2rad`, `nu_rad2deg`, `nu_turn`) | seed-min, gen2, native | `test-stdlib-modules` |
| `stdlib/decimal.sa` | exact, bounded decimal-string validation, normalization, comparison, addition, subtraction, multiplication, rounded division and rounding | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/json_decimal.sa` | exact decimal reads and updates of existing JSON numbers | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/list_algo.sa` | 21 typed list algorithms (`la_insert_sorted`, `la_sort`, `la_sorted`, `la_index_of`, `la_append`, `la_slice`, `la_take`, `la_drop`, `la_cumsum`, `la_repeat`, `la_scale`, `la_offset`, `la_zip_add`, `la_count_gt`, `la_remove_at`, `la_insert_at`, `la_distinct`, `la_lower_bound`, `la_upper_bound`, `la_merge_sorted`, `la_rotate`) | seed-min, gen2, native | `test-stdlib-modules` |
| `stdlib/str_text.sa` | 22 typed byte-string helpers (`t_is_space_byte`, `t_is_digit_byte`, `t_index_of`, `t_last_index_of`, `t_slice`, `t_trim_left`, `t_trim_right`, `t_trim`, `t_cmp`, `t_is_digits`, `t_pad_left`, `t_pad_right`, `t_word_count`, `t_replace`, `t_remove`, `t_hash`, `t_parse_uint`, `t_uint_str`, `t_count_char`, `t_starts_with`, `t_ends_with`, `t_normalize_ws`) | seed-min, gen2, native | `test-stdlib-modules`, `test-stdlib-next` |
| `stdlib/json_util.sa` | flat-object JSON build/read (`j_escape`, `j_kv_text`, `j_kv_number`, `j_kv_flag`, `j_pair`, `j_obj`, `j_arr_numbers`, `j_has`, `j_get_text`, `j_get_number`, `j_get_flag`) | seed-min, gen2, native | `test-stdlib-modules` |
| `stdlib/json_deep.sa` | nested JSON reader and bounded mutations (`jd_set_raw`, `jd_delete_raw`, `jd_object_put_raw`, `jd_array_insert_raw`, `jd_object_ensure_raw`, `jd_valid`, `jd_type`, `jd_has`, `jd_raw`, `jd_text`, `jd_num`, `jd_flag`, `jd_len`, `jd_key`); dotted paths with dot-separated numeric indexes, 15 pinned refusals, agrees with `json_util.sa` on flat objects | seed-min, gen2, native | `test-stdlib-json-deep` |
| `stdlib/json_write.sa` | nested JSON writer, functional object mutator (`jw_obj_set`, `jw_obj_del`), minifier (`jw_minify`) and multi-level pretty-printer (`jw_pretty`), round-tripping through `json_deep.sa`; boundary/precision oracle in `selfhost/stdlib_json_boundary.want` | seed-min, gen2, native | `test-stdlib-json-write`, `test-stdlib-next` |
| `stdlib/crypto.sa` | SHA-256 and HMAC-SHA256 (`cx_sha256`, `cx_sha256_list`, `cx_sha256_raw`, `cx_hmac`, `cx_hmac_list`, `cx_hmac_raw`, `cx_hex`, `cx_hex_byte`, `cx_unhex`, `cx_bytes`, `cx_eq_hex`); FIPS 180-4 and RFC 4231 vectors, cross-checked against `sha256sum` when it is installed | seed-min, gen2, native | `test-stdlib-crypto` |
| `stdlib/csv.sa` | RFC 4180-style CSV **row** codec (`csv_parse_row`, `csv_is_valid_row`, `csv_write_row`, `csv_ok`, `csv_count`, `csv_at`, `csv_push`, `csv_empty`, `csv_needs_quote`, `csv_quote`); quoted fields, embedded commas/CR/LF, doubled quotes, three malformed-row refusals | seed-min, gen2, native | `test-stdlib-csv` |
| `stdlib/csv_table.sa` | whole CSV documents, validated packed tables, updates, filtering and projection | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/csv_query.sa` | stable CSV joins, distinct, sorting and exact decimal aggregates | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/store.sa` | in-memory relational store (`db_*`): typed table shape, `db_insert`, filtered `db_update`/`db_delete`, `db_project`, stable `db_sort`, comparison and text predicates, per-row arithmetic filters, and packed-row/frame round trips; 58 `make` definitions (21 public helpers plus the encoding and predicate helpers they are built on), every operation bounded and every refusal returning `""` | seed-min, gen2, native | `test-stdlib-store` |
| `stdlib/store_index.sa` | derived indexes over `stdlib/store.sa` tables (`ix_*`): `ix_hash_build`/`ix_ordered_build`, exact-key `ix_lookup`/`ix_rows_for`/`ix_count_key`, binary-searched `ix_range`/`ix_between`, `ix_min_key`/`ix_max_key`/`ix_rows`, and staleness detection (`ix_stale`/`ix_valid`) that refuses to answer from a snapshot the table has outgrown; 43 `make` definitions | seed-min, gen2, native | `test-stdlib-store` |
| `stdlib/store_rel.sa` | relational algebra over `stdlib/store.sa` tables (`sr_*`): `sr_join`/`sr_left_join` on exact keys, `sr_group_count`/`sr_group_sum`/`sr_group_min`/`sr_group_max`/`sr_group_avg` (integer average with visible remainder), `sr_distinct`/`sr_distinct_rows`, and `sr_union`/`sr_intersect`/`sr_except`/`sr_same_rows`; accepts table frames and store states alike; 36 `make` definitions | seed-min, gen2, native | `test-stdlib-store` |
| `stdlib/url.sa` | percent-encoding/decoding (`surl_encode`, `surl_decode`, `surl_decode_ok`) and packed query strings (`surl_query_parse`, `surl_query_write`, `surl_query_push`, `surl_query_count`, `surl_query_key`, `surl_query_value`, `surl_query_get`, `surl_query_has`, `surl_query_empty`) | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/datetime.sa` | proleptic Gregorian calendar: `dt_is_leap`, `dt_days_in_month`, `dt_valid`, `dt_jdn`, `dt_from_jdn`, `dt_weekday`, `dt_weekday_name`, `dt_month_name`, `dt_day_of_year`, `dt_days_between`, `dt_add_days`, `dt_format`, `dt_parse`, `dt_istr` | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/hash.sa` | non-cryptographic checksums: `sh_sum_bytes`, `sh_is_digits`, `sh_poly`, `sh_djb2`, `sh_poly131`, `sh_sdbm`, `sh_adler32`, `sh_luhn_sum`, `sh_luhn_check_digit`, `sh_luhn_valid`, `sh_istr` | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/statistics.sa` | numeric list sum, mean, minimum, maximum, population variance and dot product | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/text_search.sa` | byte substring search, non-overlapping count and replacement | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/hex_text.sa` | hexadecimal codec for NUL-free byte strings, with explicit validation | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/geometry.sa` | 2D squared distance, cross product, rectangle area/containment and interval overlap | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/ascii.sa` | ASCII classification, byte-wise case conversion and identifier validation | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/vector.sa` | numeric vector add, subtract, scale, dot product and squared lengths/distances | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/interval.sa` | closed intervals: containment, clamping, overlap and interpolation | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/fields.sa` | unquoted byte-delimited field count and indexed access | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/duration.sa` | elapsed whole seconds as hours, minutes, seconds or H:MM:SS | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/running.sa` | prefix minima/maxima and consecutive differences of numeric lists | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/ai.sa` | flat matrices, regression and one-hidden-layer training, dense inference, activations, metrics, normalization and nearest-neighbour primitives | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/llm.sa` | byte tokens, bounded embedding lookup, multi-head attention, transformer-block inference and toy autoregressive generation | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/llm_model_io.sa` | bounded versioned JSON model interchange for the one-block CPU model | seed-min, gen2, native | `test-stdlib-next` |
| `stdlib/llm_safetensors.sa` | bounded SafeTensors F32 reader for the custom one-block model | seed-min, gen2, native (byte-list parser); file reading on gen2 | `test-stdlib-next` |

## Toolbox modules

```sayanox
use "stdlib/statistics.sa"
use "stdlib/text_search.sa"
use "stdlib/hex_text.sa"
use "stdlib/geometry.sa"
use "stdlib/ascii.sa"

hold readings = [1, 2, 3, 4]
show stats_mean(readings)                 // 2.5
show ts_replace("one one", "one", "1")  // 1 1
show hx_encode("Hi")                     // 4869
show geo_distance_squared(0, 0, 3, 4)   // 25
show ascii_identifier("name_1")           // 1
```

* Statistics use IEEE doubles. Empty aggregates and mismatched dot products
  return zero; `stats_variance` is population variance, not sample variance.
* Text search is byte-based, not Unicode-aware. Search accepts whole byte
  positions under 1e15 (negative positions clamp to zero); empty needles match
  at the requested position. Counting and replacing use non-overlapping
  matches, and an empty needle counts zero or leaves the string unchanged.
* Hex output is lowercase and input accepts either case. `hx_valid` rejects
  malformed, odd-length and NUL-containing decoded input; `hx_decode` returns
  an empty string on failure, so use `hx_valid` to distinguish failure from a
  valid empty string. This is a codec, not cryptography.
* Geometry normalizes rectangle bounds and includes edges for containment;
  `geo_overlap` returns interval overlap length, zero for touching/disjoint.
* ASCII helpers do not perform Unicode case folding. Bytes outside ASCII are
  unchanged by case conversion and rejected by identifier validation.

### Additional modules

```sayanox
use "stdlib/vector.sa"
use "stdlib/interval.sa"
use "stdlib/fields.sa"
use "stdlib/duration.sa"
use "stdlib/running.sa"

hold a = [1, 2, 3]
hold b = [4, 5, 6]
show vec_dot(a, b)                 // 32
show iv_contains(5, 1, 3)         // 1
show fields_get("red|blue", 124, 1) // blue
show dur_format(90061)            // 25:01:01
hold highs = run_prefix_max(a)
show highs[2]                     // 3
```

* Vector and running transforms create new numeric lists. Pairwise vector
  operations require equal lengths: list operations return an empty list on
  mismatch, scalar operations return zero. Callers can compare lengths first
  to distinguish a mismatch from a legitimate empty/zero result.
* Intervals are closed and normalize reversed bounds; touching intervals
  overlap with zero overlap length. `iv_lerp` is not clamped.
* Fields are byte-delimited, without CSV escaping or quoting. Delimiters must
  be integral bytes 1–255; empty and trailing fields are retained. An empty
  result from `fields_get` can mean either an empty or an absent field; use
  `fields_count` to distinguish them.
* Duration helpers accept non-negative integral seconds below 10^15, use
  elapsed rather than clock hours, and return zero or an empty string for
  invalid input. Use `dur_valid` to distinguish invalid input from zero.
* Running helpers produce prefix extrema or consecutive differences; empty
  inputs produce empty lists. All numeric operations use IEEE doubles.

`selfhost/stdlib_text.want` includes a hand-written toolbox oracle exercised by
`test-stdlib-next` on seed-min, gen2 and native.

## AI and machine-learning primitives

`stdlib/ai.sa` provides a small, deterministic numeric foundation for ML, not
an LLM, an automatic differentiation framework, or a GPU runtime. Lists contain
numbers (IEEE doubles); matrices are flattened **row-major**. A linear model
has one weight per feature followed by a bias. For example:

```sayanox
use "stdlib/ai.sa"
hold inputs = [0, 1]        // two rows, one feature
hold targets = [1, 3]
hold initial = [0, 0]       // weight, bias
hold model = ai_linear_fit(inputs, targets, initial, 0.1, 100)
hold predictions = ai_predict(inputs, model)
show ai_mse(predictions, targets) < 0.001  // 1
```

The complete runnable example is `examples/ai_linear.sa`. API overview:

* `ai_is_integer`, `ai_matrix_valid`, `ai_model_valid` validate dimensions;
  `ai_dot`, `ai_argmax`, `ai_relu`/`ai_relu_list` and `ai_threshold` are
  basic inference utilities. `ai_argmax` returns the first maximum or -1.
* `ai_linear` predicts one row; `ai_predict` predicts a flat matrix.
  `ai_linear_step` performs one full-batch gradient step on mean squared
  error; `ai_linear_fit` repeats it at most 10,000 times. Both use fresh
  models, never mutate inputs, and return `[]` on invalid shape, empty
  training data, or non-positive learning rate. Zero steps returns a copy.
* `ai_mse`, `ai_mae`, and exact-label `ai_accuracy` return zero for empty or
  mismatched inputs, so validate lengths before interpreting the result.
* `ai_sigmoid`, `ai_sigmoid_list`, and `ai_softmax` provide activation
  functions. `ai_exp` is a dependency-free approximation: it clamps its input
  to [-30, 30], applies a degree-16 Taylor expansion after range reduction,
  and squares five times. Softmax subtracts the maximum logit before applying
  it; differences below -30 are floored, so tiny probabilities are approximate.
* `ai_logistic_predict`, `ai_logistic_step`, and `ai_logistic_fit` provide
  binary logistic inference and full-batch gradient training with labels 0/1,
  the same model layout and limits as linear training, and no regularization.
  Sigmoid saturation makes the computed gradient an approximation at extreme
  logits. `ai_binary_loss_valid` validates probabilities and labels;
  `ai_binary_loss` computes mean cross-entropy with approximate logarithms
  and clamps endpoint probabilities to [1e-12, 1-1e-12]. Invalid or empty
  inputs return zero, so check validity first. See `examples/ai_logistic.sa`.
* `ai_dense` performs one affine layer with output-major flat weights and one
  bias per output. Compose it with `ai_relu_list` for inference. It does not
  train this layer directly.
* `ai_nn_shape_valid`, `ai_nn_predict`, `ai_nn_step` and `ai_nn_fit` implement
  a **one-hidden-layer binary classifier**: hidden ReLU and a sigmoid output,
  trained by full-batch cross-entropy backpropagation. For C input features
  and H hidden units, the flat model contains H*C hidden-major input weights,
  H hidden biases, H output weights, then one output bias. C and H are each
  limited to 1–64; the training feature count is inferred from the data and
  label lengths. Training requires binary labels, nonempty data, a positive
  rate and 0–10,000 integer steps. Invalid input returns `[]`; zero steps
  copies the model. ReLU has derivative zero at exactly zero. Initialize
  hidden units asymmetrically to avoid identical units; all-zero initialization
  can prevent learning. The example `examples/ai_neural.sa` trains XOR.
* `ai_standardize` applies supplied means and nonzero scales to each feature;
  fit preprocessing parameters on training data and reuse them during
  inference. `ai_nearest` returns the first nearest row by squared Euclidean
  distance, or -1 on invalid/empty data.

List-returning operations return `[]` on shape errors, which is also a valid
empty result in some cases. Validate inputs explicitly when that distinction
matters. Callers must provide finite values; floating-point overflow and NaN
are not detected. Gradient descent is sensitive to data scale and learning
rate and is not guaranteed to converge. This is a small-data, CPU-only
implementation, with no model persistence, autodifferentiation, GPU, or pretrained model. Its checked-in hand-computed oracle tests linear, logistic and neural training,
including one analytically checked backprop step and XOR, shape refusals,
metrics, ties, standardization and dense inference on all three backends via
`test-stdlib-next`.

## CSV documents and tables

`stdlib/csv_table.sa` builds on `stdlib/csv.sa` for complete multi-row CSV
rather than single records. Import the row module before the table module:

```sayanox
use "stdlib/csv.sa"
use "stdlib/csv_table.sa"
hold table = ct_parse("name,role\r\nAda,engineer\r\nMina,designer\r\n")
hold engineers = ct_filter_eq(table, 1, "engineer", 1)
show ct_cell(engineers, 1, 0)  // Ada
```

* `ct_parse` accepts LF and CRLF record separators, with commas, doubled
  quotes and CR/LF inside quoted fields. Bare CR outside quotes, unclosed
  quotes, quotes in unquoted fields and text after a closing quote are refused.
  Rows may have different widths. Empty input has zero rows; a blank line is
  one empty field; a final record separator adds no extra row.
* Tables are opaque packed strings containing the existing packed-row format.
  `ct_valid` validates both levels even for malformed caller-supplied data.
  `ct_row_count` and `ct_columns` return -1 for invalid/missing data;
  `ct_row` and `ct_cell` return an empty string for missing data, so use the
  counts to distinguish a missing cell from an empty one.
* `ct_append` and `ct_set` return new tables; `ct_header_index` finds the first
  exact header match. `ct_filter_eq` can preserve the header and skips rows
  missing the selected column. `ct_select` projects an ordered list of column
  indexes, allowing duplicates but refusing a missing column in any row.
  Invalid updates return `!`, which `ct_valid` rejects.
* `ct_write` emits CRLF separators and quotes fields as needed. A final empty
  record is terminated so parse/write preserves it; the single literal `!`
  is quoted to reserve the error marker. An invalid table or output over the
  byte cap returns `!`.

Inputs and packed/output strings are capped at 262144 bytes, with at most
1024 rows and 1024 fields per row. This is an in-memory implementation, not a
streaming parser; repeated packed-string construction and lookups can be
costly for large tables. Strings are byte strings, not Unicode-aware text.
Boundary, malformed-frame and parse/write round-trip tests are checked across
seed-min, gen2 and native via `test-stdlib-next`. See `examples/csv_table.sa`.

### CSV table queries

`stdlib/csv_query.sa` adds relational-style operations. Import `csv.sa`,
`csv_table.sa` and `decimal.sa` before it; see `examples/csv_query.sa`.

* `cq_join(left, right, left_col, right_col, keep_header)` is a stable inner
  join on exact byte-string keys, emitting all left fields followed by all
  right fields. Duplicate keys produce all matches in left-major/right-major
  order. Missing join keys in data rows are skipped. With `keep_header = 1`,
  both headers must exist and contain their join columns.
* `cq_distinct(table, col, keep_header)` retains the first row per exact key.
  `cq_sort(table, col, descending, keep_header)` performs stable bytewise
  lexical sorting; this is neither numeric nor locale/Unicode collation. Both
  reject data rows missing the selected column.
* `cq_sum` and `cq_mean` aggregate string-encoded decimals without double
  conversion. Mean accepts a precision and uses nearest/ties-away-from-zero
  rounding. Sum of an empty data set is `0`; mean of one is invalid.
  `cq_group_sum(table, key_col, value_col, keep_header)` returns two columns
  in first-seen key order. Its header, when requested, uses the original
  column names. Missing cells, invalid decimal values, sums beyond 256 digits
  and invalid flags are refused rather than silently skipped. `cq_sum` and
  `cq_mean` signal errors with the empty string; table operations return `!`.

All `keep_header`, `skip_header` and `descending` flags are 0 or 1. Join and
group results obey the 1024-row, 1024-field and 262144-byte table caps. These
are bounded in-memory operations; join, distinct, grouping and sorting can be
quadratic or worse due to packed-string scans and should be used for small
tables. They do not implement SQL or streaming. Tests exercise ordering, ties,
ragged rows, invalid input, join expansion limits, exact large values and
rounding on seed-min, gen2 and native via `test-stdlib-next`.

## Relational store

`stdlib/store.sa` is the database module: an in-memory relational store with
insert, filtered update and delete, projection, sorting and predicates. It is
independent of the CSV modules -- it does not parse CSV -- but it exchanges data
with them through the same packed row form and can be written to a file as a
single frame.

```sayanox
use "stdlib/store.sa"
hold staff = db_insert(db_new(3), "1,Ada,36")
staff = db_insert(staff, "2,Mina,41")
hold older = db_where_n(staff, "2:>:38")
show db_hits(older)                        // 1
show db_get(staff, db_hit(older), 1)       // Mina
show db_rows(db_update(older, 2, "42"))    // 1,Ada,36 then 2,Mina,42
```

* A table is one flat string: a row count, a column count and the cells in
  row-major order, separated by `chr(31)`. `db_new(cols)` fixes the shape, so an
  empty table still knows its column count, and `db_insert` refuses a row with
  the wrong arity, an empty row, or a cell containing a separator byte, a newline,
  a tab or a comma. Those refusals are what make every later scan unambiguous.
* A query is `column:operator:value`. `=` and `!=` compare stored bytes, which
  keeps identifiers exact; `<`, `<=`, `>` and `>=` compare numerically when both
  sides are decimal numbers and bytewise otherwise, so `"9"` sorts below `"10"`
  while names still sort by byte. `has`, `^` and `$` are byte-exact substring,
  prefix and suffix tests -- there is no case folding and no Unicode awareness.
* A value may start with `~` to name an arithmetic expression over the matching
  row's own cells (`a` is its first cell, `b` its second): `2:>:~a+30` selects
  rows whose third cell exceeds their first cell plus 30. Exactly one operator and
  two operands are supported; a chained expression such as `~a+1+1` is refused
  rather than given an invented precedence.
* `db_where` selects the first matching row and `db_where_n` selects all of them.
  The selection lives in the returned state (table, then `chr(30)`, then a
  comma-separated row list, then `chr(30)`, then the sort column), so a filtered
  result feeds straight back into `db_update`, `db_delete` or `db_project`. An
  empty selection is a refusal, never a whole-table write: `db_update` and
  `db_delete` on an unselected table return `""`.
* `db_sort` returns a new table in ascending stable order and clears the
  selection. `db_project` returns a new table with the listed column indexes in
  the listed order, so a repeated index duplicates a column.
* `db_rows` and `db_from_rows` convert to and from the `a,b,c` line per row form
  used by `stdlib/csv_table.sa`; `db_table_frame` and `db_frame` produce strings
  for `write_file`, and `db_frame_table` reads either back.

Bounds are explicit and refusals are empty strings, so checking `len(x) == 0`
is always safe: 64 columns, 4096 rows, 1024 bytes per cell, 8 selected rows (a
ninth match refuses the query) and 128 rows for a sort, which is a stable
insertion sort over string-encoded rows. Malformed queries, unknown operators
and impossible column indexes are refused rather than answered wrongly; the
fixture's 23 refusal lines pin each one.

There is no persistence engine, no transactions, no secondary index, no wire
protocol and no SQL parser: this is a bounded in-memory store for small
datasets, and every operation rebuilds a string. The full 150-line fixture
(`selfhost/stdlib_store_test.sa`) is compared byte for byte against
`selfhost/stdlib_store.want`, an oracle computed by an independent Python
implementation, on seed-min, gen2 and native via `test-stdlib-store`.

## Derived indexes

`stdlib/store_index.sa` builds indexes over a `stdlib/store.sa` table. Import
`store.sa` first.

```sayanox
use "stdlib/store.sa"
use "stdlib/store_index.sa"
hold staff = db_insert(db_new(3), "1,Ada,36")
staff = db_insert(staff, "2,Mina,41")
staff = db_insert(staff, "3,Ada,29")
hold by_name = ix_hash_build(staff, 1)
show ix_rows_for(by_name, staff, "Ada")      // 0,2
hold by_age = ix_ordered_build(staff, 2)
show ix_range(by_age, staff, ">=", "36")     // 0,1  (key order, not table order)
show ix_key_at(by_age, 0)                    // 29
```

* `ix_hash_build(table, col)` keeps one entry per distinct key with the rows
  holding it, in first-seen order: `ix_lookup` returns the first such row, and
  `ix_rows_for`/`ix_count_key` return all of them and their count. Keys repeat
  freely, which is why a key maps to a row list rather than to a single row.
* `ix_ordered_build(table, col)` keeps every row in ascending key order.
  `ix_range(index, table, op, value)` binary-searches it for `=`, `>`, `>=`,
  `<` and `<=`, and `ix_between(index, table, lo, hi)` answers an inclusive
  range. Rows come back in **key order**, which is not the order `db_where_n`
  reports; `parity.*` lines in the fixture pin the sets and the bounds both.
* Ordering uses the store's own rule (numeric when both sides are numbers,
  bytewise otherwise), so `"9"` orders below `"10"` and `"A"` before `"a"`. An
  index and a scan therefore never disagree about what "greater" means.
* An index is a **snapshot**: it records the table's row count, column count and
  a folded byte sum. `ix_stale(index, table)` reports a mutation and
  `ix_valid` is its inverse; every lookup, count and range on a stale index
  returns `""` rather than a row number that no longer means anything. Rebuild
  after a mutation instead of trusting the old index.
* Bounds are the store's bounds plus an index-specific cap of 128 distinct keys
  (hash) and 128 rows (ordered), because past that the bookkeeping costs more
  than the scan it replaces. Keys may hold any byte except `chr(28)`-`chr(31)`;
  an empty key is a legitimate entry for a NULL cell.
* This is not a durable database index: there is no B-tree, no page layout, no
  incremental maintenance, and no concurrency. Every build is a full pass, so it
  pays off when one index answers many queries.

`selfhost/stdlib_store_index_test.sa` (89 lines) is compared byte for byte
against `selfhost/stdlib_store_index.want`, again computed from an independent
Python reference, on seed-min, gen2 and native by `test-stdlib-store`.

## Joins, grouping and set operations

`stdlib/store_rel.sa` answers the questions that need two tables or a grouping
pass. Import `store.sa` first; `store_index.sa` is independent of it.

```sayanox
use "stdlib/store.sa"
use "stdlib/store_rel.sa"
hold staff = db_insert(db_new(3), "1,Ada,10")
staff = db_insert(staff, "4,Ravi,10")
hold dept = db_insert(db_new(2), "10,eng")
show db_rows(sr_join(staff, 2, dept, 0))       // 1,Ada,10,10,eng then 4,Ravi,10,10,eng
show db_rows(sr_left_join(staff, 2, dept, 0))  // adds an unmatched row when there is one
hold sales = db_insert(db_new(3), "eng,Ada,10")
sales = db_insert(sales, "eng,Mina,20")
show db_rows(sr_group_sum(sales, 0, 2))        // eng,30
show db_rows(sr_group_avg(sales, 0, 2))        // eng,15,0,2
```

* **Keys match on exact bytes.** `"42"` and `"042"` are different keys even though
  the store's ordering predicates call them numerically equal: matching is
  equality, and equality here is byte equality. A NULL key (empty cell) matches
  only another NULL key.
* **`sr_join`** emits all left cells then all right cells, one row per matching
  pair, left-major then right-major. **`sr_left_join`** emits an all-NULL right
  half for an unmatched left row, so the output width never varies and a fixed
  column list stays valid.
* **Aggregates** report groups in first-seen key order. `sr_group_avg` returns
  four columns — quotient, remainder, count — because the average is integer
  division and hiding the truncation would be a lie. `sr_group_min`/`sr_group_max`
  seed from the first non-NULL value, so an all-NULL group reports NULL rather
  than 0, while `sr_group_sum` treats NULL as 0 and keeps the group.
* **An aggregate over text is refused**, not evaluated: summing names would
  silently add zeros. The whole call returns `""`.
* **Set operations keep duplicates**: `sr_union` is concatenation, `sr_intersect`
  and `sr_except` are the `ALL` variants that keep left-side duplicates, and
  `sr_distinct_rows` removes whole-row duplicates in first-seen order.
  `sr_same_rows` compares two tables ignoring order and duplicates.
* **Frames and states both work.** Every function accepts what `db_insert` returns
  (a state) and what `db_table_frame` returns (a bare frame); the fixture pins
  that both give the same answer, so a caller never has to remember which one it
  is holding.
* A join result is capped at 4096 rows, so a cartesian product of two wide tables
  is refused rather than materialised; 64 x 64 is inside the cap and produces
  every pair.

`selfhost/stdlib_store_rel_test.sa` (104 lines) is compared byte for byte against
`selfhost/stdlib_store_rel.want`, computed from a third independent Python
reference, on seed-min, gen2 and native by `test-stdlib-store`.

## Exact decimals in JSON

`stdlib/json_decimal.sa` composes `json_deep.sa` with `decimal.sa` to update
existing JSON numeric values without conversion through `jd_num` or IEEE
floating-point numbers. Import both dependencies before the module:

```sayanox
use "stdlib/json_deep.sa"
use "stdlib/decimal.sa"
use "stdlib/json_decimal.sa"
hold doc = "{\"id\":9007199254740993,\"price\":0.1}"
show jdec_add(doc, "price", "0.2")
// {"id":9007199254740993,"price":0.3}
```

`jdec_read` returns the canonical exact decimal string. `jdec_set`, `jdec_add`,
`jdec_sub`, `jdec_mul`, `jdec_div` and `jdec_round` return updated JSON while
preserving all bytes outside the target. Every operation validates the full
JSON document and requires an existing number at the dotted raw-key/array-index
path; duplicate keys follow the reader's first-match rule. Empty string means
failure, including malformed JSON, absent or nonnumeric paths, invalid or
overflowing decimal operands and division by zero. Decimal numbers with JSON
exponent notation are valid JSON but **not supported** by this decimal
representation and are refused; normal `jd_num` still uses IEEE doubles.
Division and rounding follow `decimal.sa`'s nearest, ties-away-from-zero rule.
The existing 256-digit decimal limit applies. The boundary oracle exercises
large integers, precision, whitespace preservation, duplicate keys, failure
cases and rounding on seed-min, gen2 and native via `test-stdlib-next`. See
`examples/json_exact_decimal.sa`.

## LLM inference building blocks

`stdlib/llm.sa` is an experimental **CPU-only** set of transformer building
blocks, not a complete language model. Import `stdlib/ai.sa` before it:

```sayanox
use "stdlib/ai.sa"
use "stdlib/llm.sa"
hold ids = [0, 1]
hold embeddings = llm_embed(ids, [1, 0, 0, 1], 2)
hold result = llm_attention(embeddings, embeddings, embeddings, 2)
```

* `llm_bytes` yields NUL-free input bytes as numeric token IDs; this is not
  BPE or compatible with a pretrained tokenizer.
* `llm_embedding_valid` checks IDs and a flat vocabulary-by-width embedding
  table. `llm_embed` looks up rows, with limits of 256 tokens, vocabulary rows
  and embedding dimensions. Invalid input and empty input both return `[]`.
* `llm_attention_valid` and `llm_attention` implement single-head scaled
  causal attention on equal-shaped, row-major Q/K/V matrices, limited to 64
  tokens and 64 dimensions. Each position sees only itself and earlier tokens.
  Softmax uses `ai_exp`'s documented approximate -30 floor. The full-sequence implementation
  is quadratic in context length.
* `llm_multihead_valid` and `llm_multihead` apply independent causal attention
  to adjacent head slices of pre-projected Q/K/V. The number of heads must
  divide the width; token and width caps remain 64. The output concatenates
  heads in feature order and does not apply an output projection.
* `llm_cache_append` returns a fresh K or V cache with one projected row
  appended (maximum 64 rows, width 1–64). `llm_attention_step_valid` and
  `llm_attention_step` evaluate one query against caller-owned K/V caches,
  including the current token's already-appended K/V. For the same prefix,
  the step equals the corresponding row of full causal multi-head attention.
  Both caches must have equal shape; invalid inputs return `[]`. This is an
  inference primitive, not an automatic cache manager or generation loop.
  Copying on append is linear in cache size; no GPU or in-place optimization
  is implied. See `examples/llm_cache.sa`.
* `llm_bytes_valid` and `llm_bytes_decode` provide a byte-token round trip.
  NUL, nonintegral and out-of-range IDs are rejected; valid empty output and
  invalid input both decode to an empty string. This is not UTF-8 validation.
* `llm_layernorm_valid` and `llm_layernorm` perform per-row population layer
  normalization with gamma and beta. Width and row count are limited to 64;
  input values must lie in [-1e6, 1e6] and epsilon in [1e-12, 1e6]. The
  bounded square root is approximate. Gamma, beta and all inputs must be
  finite; validators do not test for NaN. Invalid or empty results are `[]`.
* `llm_project_valid` and `llm_project` apply output-major affine weights to
  each row (up to 64 tokens and 64 input/output features). `llm_add` adds
  equal-length flat lists for residual connections or positional embeddings.
  Invalid shapes and valid empty data may both produce `[]`.
* `llm_block_valid` and `llm_block` implement one **pre-norm** CPU inference
  block: layernorm, Q/K/V projections, multi-head causal attention and output
  projection plus residual; then layernorm, affine-ReLU-affine feed-forward
  plus residual. For width W and feed-forward width F the flat parameters are,
  in order: norm1 gamma and beta (W each); Q, K, V, O output-major weights
  (W*W) and biases (W), interleaved; norm2 gamma and beta (W each); FF1
  output-major weights (F*W) and bias (F); FF2 output-major weights (W*F)
  and bias (W). The total is `4*W*W + 2*W*F + 9*W + F`. W is 1–16, F is
  1–64, heads must divide W, context is at most 64. Layernorm epsilon and
  numeric bounds are as above. The second layernorm can refuse an out-of-range
  intermediate even when `llm_block_valid` accepted the initial inputs.
  Empty input and invalid execution both return `[]`. This implements a
  particular ReLU pre-norm architecture, not general model compatibility,
  training, positional encoding or cached block decoding. See
  `examples/llm_block.sa` for toy weights.
* `llm_model_valid`, `llm_model_logits` and `llm_generate` implement a small
  one-block **greedy autoregressive** CPU model. The config is
  `[vocab, width, ff_width, heads, epsilon, context, eos, max_new_tokens]`;
  the flat model is token embeddings `[vocab,width]`, learned positional
  embeddings `[context,width]`, the block parameters described above,
  output-major logits weights `[vocab,width]`, then logits biases `[vocab]`.
  Vocab/context <=64, width <=16, FF width <=64, and max tokens <=64. The
  prompt must contain at least one in-vocabulary integer ID and fit in the
  context. EOS is -1 to disable it; otherwise a generated EOS is included in
  the output and stops generation. When the context is already full, one
  final token can still be predicted. Invalid inputs, zero output length or
  a numerical range refusal may all return `[]`. Values must be finite;
  there is no overflow/NaN detection. `llm_model_valid` checks structure,
  not every intermediate. The entire prefix is recomputed at each step; this
  is deterministic but not an optimized or pretrained LLM. See
  `examples/llm_generate.sa` for a small hand-constructed model.
* `llm_bigram_valid` and `llm_bigram_generate` provide deterministic greedy
  decoding from a supplied V-by-V bigram logits table (V <= 64, at most 256
  generated tokens). The prompt token is not included, the emitted EOS is
  included, and -1 disables EOS; ties choose the lowest ID. A zero limit and
  invalid requests both return `[]`, so validate first. This is a toy bigram
  model and **not** a transformer generation loop. See `examples/llm_bigram.sa`.
* `llm_logits` applies an output-major affine projection; `llm_greedy` chooses
  the first largest score or -1 for empty logits. `examples/llm_attention.sa`
  demonstrates the path with toy weights; those weights are not trained.
  `examples/llm_multihead.sa` composes projection, multi-head attention, a
  residual connection and layer normalization using toy weights.

### Bounded CPU model interchange

`stdlib/llm_model_io.sa` imports and validates the **custom** one-block model
format shown in `examples/llm_toy_model.json`. Import `stdlib/json_deep.sa`,
`stdlib/ai.sa`, `stdlib/llm.sa` and then `stdlib/llm_model_io.sa`:

```sayanox
hold doc = read_file("examples/llm_toy_model.json")
hold valid = llm_io_valid(doc)
hold config = llm_io_config(doc)
hold weights = llm_io_weights(doc)
hold output = llm_generate([0], weights, config)
```

The JSON object must have exactly `format`, `config`, and `weights` fields.
`format` is `sayanox-llm-v1`; the other arrays use the exact flat model
layout and configuration described above. Documents are capped at 256 KiB,
weights at 8192 numbers, and each numeric token at 24 bytes. Only ordinary
JSON decimal notation is supported (no exponent), with absolute value at most
one million. Values become IEEE doubles. Validation checks the complete JSON,
shapes, dimensions, and token bounds; inference can still reject out-of-range
intermediates. Invalid data returns `0` from `llm_io_valid` and empty lists
from the accessors. The accessors validate independently and return fresh
lists. **Enforce a file size limit before `read_file` for untrusted files:**
the built-in reads the file before the in-memory size check can run.

The sample contains hand-authored toy weights, not pretrained weights. This
JSON format does **not** import GGUF, safetensors, Hugging Face, ONNX or arbitrary
pretrained architectures, and it cannot execute on a GPU. Those capabilities
require model-specific architecture/tokenizer support, binary loaders, GPU
device/kernel integration and real-hardware testing. See
`examples/llm_model_file.sa` for the complete runnable CPU example.

### SafeTensors for the custom CPU model

`stdlib/llm_safetensors.sa` reads a standard SafeTensors byte container for
**this repository's specific one-block architecture**, not arbitrary
pretrained models. Import `json_deep.sa`, `ai.sa`, `llm.sa` and then
`llm_safetensors.sa`. Provide a list of integer bytes to:

* `llm_safetensors_valid(bytes)` checks framing, JSON, required metadata,
  F32 tensor shapes, contiguous offsets, finite values and model dimensions.
* `llm_safetensors_config(bytes)` and `llm_safetensors_weights(bytes)` return
  fresh lists or `[]` on invalid data, usable with `llm_generate`.

The header must have exactly `__metadata__`, `config`, and `weights` entries;
metadata is `{ "format": "sayanox-llm-v1" }`. Both tensors are rank-one
little-endian F32, with config of length eight followed by weights in the
layout above. Exponents, offsets and shape integers use strict unsigned decimal
header notation; NaN, infinity, magnitudes above 1e6, gaps, overlap, trailing
bytes, unsupported dtypes and malformed shapes are rejected. F32 values are
converted to IEEE doubles, including subnormals. The parser caps the entire
buffer at 1 MiB, header at 64 KiB, and each tensor at 8192 elements; these are
small-model limits, not a general large-model loader. Byte inputs must be
finite integers 0–255. Parsing, not reading, is bounded: enforce file-size
limits before loading an untrusted file.

`examples/llm_toy_model.safetensors` is a tiny hand-authored example, not a
pretrained model. `examples/llm_safetensors_file.sa` uses `read_bytes` and runs
on gen2; seed-min and native AOT do not support `read_bytes`. The byte-list
parser itself is checked on all three backends against a pinned binary fixture,
plus malformed framing, offsets, dtype, NaN, infinity and truncation controls.
The example file was also read with the independent Python `safetensors` 0.8.0
parser. Actual pretrained models still need matching architectures, tokenizers,
parameter mappings and tests with real weights. No GPU execution is provided.

Callers must provide finite numeric values. The validators check dimensions
and token IDs, not NaN/overflow. Tests cover causal masking, per-head scaling, normalization, invalid
shapes, caps and projection using independent expected outputs on
seed-min, gen2 and native (`test-stdlib-next`). No pretrained weights,
general pretrained model compatibility, a pretrained tokenizer, GPU kernels or GPU
device runtime are provided. GPU support would require an actual device
backend and hardware tests; CPU execution must not be described as GPU support.

## Exact decimal strings

`stdlib/decimal.sa` is a **separate representation**, not a change to the
language's IEEE-double `num` type. It stores decimal values as strings:

```sayanox
use "stdlib/decimal.sa"
show dec_add("0.1", "0.2")              // 0.3
show dec_mul("-12.50", "0.04")          // -0.5
show dec_add("9007199254740993", "1")   // 9007199254740994
```

`dec_valid` accepts optional minus, one or more ASCII integer digits and an
optional point followed by digits. Leading and trailing zeros are permitted;
whitespace, plus signs and exponents are not. `dec_normalize` canonicalizes
zeros and sign; `dec_negate`, `dec_add`, `dec_sub`, `dec_mul`, `dec_div` and `dec_round` return
canonical strings. `dec_round` takes 0–255 fractional places and rounds to
nearest, with ties away from zero; it does not pad trailing zeros.
`dec_div(a, b, places)` uses decimal long division and the same rounding
rule, returning an empty string for division by zero or invalid places.
For example `dec_div("1", "8", 3)` is `0.125` and `dec_div("1", "3", 2)`
is `0.33`; this is rounded decimal division, not an exact rational type. `dec_compare` returns -1, 0 or 1, and **2 on invalid
input**. Other public operations return an empty string on invalid input or a
result exceeding 256 digits. Inputs are limited to 256 digits excluding sign
and point. Arithmetic is exact within those limits and uses no decimal-to-num
conversion; multiplication and division use bounded grade-school digit
arithmetic and may be slow near the limits. Exponent notation and arbitrary
unbounded precision are not provided.

`selfhost/stdlib_text.want` includes boundary cases and deterministic vectors
independently calculated using Python's `decimal` module; `test-stdlib-next`
checks byte-identical results on seed-min, gen2 and native. See
`examples/exact_decimal.sa` for a runnable example.

## Why two kinds of module

`tiny.sa` and `num_util.sa` use only numbers, `when`, `give` and recursion.
That is the subset all three backends implement in full, so those two are the
modules that can be promised on the native-AOT path without typed parameters.

The other eight modules take `str` and `list` parameters
(`make s_len(s: str) -> num`). Typed parameter and return annotations are now
accepted by seed-min, gen2 and native alike (checked on 2026-10-13 with a
`greet(name: str) -> str` / `total(xs: list) -> num` probe: seed-min and native
both print the right answer). A bare string `+` chain in a `give`
(`give "hi " + name`) used to emit `char * + char *` on gen2; that lowering
was fixed on 2026-10-13 (`test-gen2-expr-lowering`), but library code still
accumulates into a `hold` and returns that, because the pattern works on
every backend and every older gen2. One gen2 authoring rule remains load
-bearing for these modules: a comment must not contain an odd number of raw
`"` characters — gen2's typed-signature scan loses track of quotes there and
misreads the following `make` signatures (this was the actual root cause of
the `json_util.sa` gen2 failure, found 2026-10-13; balanced quotes in
comments are fine).

## Rules for adding a helper to tiny.sa

* Numbers only. These helpers avoid `hold` inside a body (native now supports it). At most 6
  parameters.
* Define a helper before any helper that calls it. A user function gets no
  forward prototype in the generated C.
* Add the expected output to a checked-in program and to a `make` target that
  requires seed-min, gen2 and native to print the same bytes. The 2026-10-10
  additions are in `selfhost/stdlib_growth_test.sa`, and their expected values
  were worked out by hand.

## Use

```sayanox
use "stdlib/tiny.sa"
show isqrt(50)        // 7
show collatz_steps(6) // 8
```

`use` is resolved relative to the file that contains it.

## `json_util.sa`: flat-object JSON, deliberately small (2026-10-13)

`j_` builds and reads **flat** JSON objects: string/number/boolean values,
plus number arrays (`j_arr_numbers`). `j_get_text`, `j_get_number` and
`j_get_flag` read the *first* `"key":` occurrence, `j_has` tests presence,
and the builders escape quotes, backslashes and control bytes. Verified
byte-identically on seed-min, gen2 and native by `test-stdlib-modules`
(`selfhost/stdlib_json_test.sa`, expected values computed by hand).

Documented non-goals, by design: nested objects/arrays as values, exponent
notation in numbers, and `\u` escapes above U+007F on the read path. A JSON
document outside that shape is not silently misread into a wrong answer the
library claims is right — it is simply outside what these helpers promise,
and this section is the promise.

## Portable interpolation helpers (2026-10-11)

`tiny.sa` adds `lerp(a,b,t)`, `saturate(x)`, `smoothstep01(x)` and
`distance_sq(x1,y1,x2,y2)`. All accept numbers and work on seed-min, gen2 and
native. `lerp` intentionally extrapolates for t outside [0,1]; `saturate`
clamps to [0,1]; `smoothstep01` clamps before applying x*x*(3-2*x).
`distance_sq` returns squared Euclidean distance, not distance. These use
double arithmetic (no promise against overflow or NaN propagation).

`test-stdlib-interpolation`, included by `test-stdlib` and `test-stdlib-growth`,
checks endpoints, fractions, extrapolation and distance on seed/gen2, and
native when built. This is a small utility library, not a full standard
library: no JSON, HTTP or cryptography implementation is added here.

## Algorithm and text modules (2026-10-13)

Three modules add 52 helpers, all in `make test-stdlib-modules`. The expected
output is 99 hand-computed values from `selfhost/stdlib_modules_test.sa`, and
seed-min, gen2 and native must print byte-identical stdout.

**`num_util.sa` (`nu_`)** — numeric helpers that need no `str` or `list`
parameter, so they run on the native-AOT subset too. The only double-to-integer
conversion the pure-min dialect offers is truncation-toward-zero through the
modulo operator (`x % 1000000000000000` truncates the fractional part because
`sx_mod` casts both operands to `long`), and every rounding helper here is
built on that one fact:

```sayanox
make nu_trunc(x) {
  give x % 1000000000000000
}
```

`nu_floor`/`nu_ceil`/`nu_round`/`nu_frac` derive from it, `nu_mod_pos` is
Euclidean modulo (the result takes the sign of the divisor, unlike `%`),
`nu_int_div` is floor division, `nu_wrap` folds a value into `[lo, hi]`,
`nu_map_range` rescales one interval onto another, `nu_median3` is the median of
three, and `nu_pi`/`nu_deg2rad`/`nu_rad2deg`/`nu_turn` cover angles.
`show` prints with `%g`, so `nu_pi()` displays as `3.14159`.

**`list_algo.sa` (`la_`)** — typed list algorithms. Every transform returns a
NEW list; none of them mutates its argument, and the fixture re-checks the
input length after each call. `la_sort` is insertion sort (`la_insert_sorted`
does one step), `la_sorted` reports whether a list is non-decreasing,
`la_slice`/`la_take`/`la_drop` clamp out-of-range indices instead of failing,
`la_distinct` keeps first occurrences, and `la_zip_add` stops at the shorter
list.

**`str_text.sa` (`t_`)** — typed, byte-oriented text helpers. Strings are C
`char *`; a "character" is one byte, so these helpers are ASCII-oriented and
will split a multi-byte UTF-8 sequence (the same limitation `str_util.sa`
documents). `t_index_of`/`t_last_index_of` return `-1` when absent, `t_slice`
clamps, `t_trim*` strip ASCII space/tab/newline/CR, `t_cmp` gives
`<0 / 0 / >0`, `t_word_count` counts whitespace-separated runs, `t_replace(s, from, to)` replaces each matching byte, not substrings, `t_hash` is a small `h * 31 + c` fold, and
`t_parse_uint` stops at the first non-digit.

The four helpers added on 2026-10-31 are oracle-gated:
`t_count_char(s, c)` counts byte occurrences (an absent byte counts 0),
`t_starts_with`/`t_ends_with` compare exact byte runs (an empty prefix/suffix
matches, a longer one never does), and `t_normalize_ws` collapses every run of
ASCII space/tab/LF/CR to one space while dropping leading and trailing
whitespace, so it is idempotent and maps whitespace-only input to `""`.
`selfhost/stdlib_text_test.sa` is a fixture with a hand-written
`selfhost/stdlib_text.want`; `test-stdlib-next` compiles it with seed-min, gen2
and native AOT and requires all three stdout streams to byte-match that file,
i.e. the expected bytes are not produced by any of the compilers under test.
The CR cases used to build the byte with `chr(13)` because the pure-min native
backend dropped `\r` from a source literal (register R13). That decoder was
fixed on 2026-10-31 and the fixture now uses source literals, so those two lines
are the R13 regression test on all three backends.

`selfhost/stdlib_json_boundary_test.sa` is the R07 oracle for the JSON pair: 43
lines covering minification with whitespace inside strings, updates on an empty
document, key prefixes (`user` vs `user_id`), first/last/absent/only-key
deletion, well-formedness of a deleted-to-empty object, nested dotted paths and
indexes, number policy (six fractional digits with trailing zeros trimmed and
the sign kept), escaping round-trips and three malformed documents that must
stay invalid. It is compared with `selfhost/stdlib_json_boundary.want` on
seed-min, gen2 and native AOT by `test-stdlib-next`.

### Rules these modules follow

* One statement per line; `give xs }` on one line is rejected.
* A helper is defined before every helper that calls it — a user function gets
  no forward prototype in the generated C.
* Bind intermediate indexed values with `hold` in portable library code;
  direct indexed returns now have their own `test-give-index` coverage.
* **An index may be a numeric expression** (`xs[i - 1]`, `xs[(a + b) / 2]`,
  `xs[p.k]`) in a value position, inside a `when`/`while` condition and inside
  a `for` bound, on all three backends since the 2026-10-13 increment
  (`make test-gen2-index-expr`). `la_sorted` uses `xs[i] < xs[i - 1]` and is
  the live stdlib exercise for it. Gen2 also supports modulo, len() and
  nested indexes; arbitrary calls, comma/string/empty indexes, unbalanced
  parentheses and trailing operators remain refused. See
  `test-gen2-index-expr` and `test-gen2-expr-lowering` for the exact boundary.
* No inline list literal as a call argument and no postfix indexing of a call
  result (`la_take(xs, 2)[1]`) in tests: bind to a `hold` first.

## Scope confirmation (2026-10-15, superseded 2026-10-22 for two items)

No nested JSON reader is provided.
`json_util` remains text building plus limited flat-object extraction, not a
validating JSON parser. It does not promise nested values, exponent parsing,
Unicode scalar validation or arbitrary escaped-key lookup. Existing module
parity tests run in the bootstrap gates; no crypto implementation is claimed.

> Superseded on 2026-10-22 by `stdlib/json_deep.sa` and `stdlib/crypto.sa`
> (see "Nested JSON and cryptography" below). The sentences above still
> describe `json_util.sa` itself, which was not changed: it is still the flat,
> non-validating module. What changed is that two *new* modules now cover the
> nested-JSON and hashing cases, each with its own gate.
HTTP/crawler integration tests are explicitly optional (`make test-network`):
they use a Python local test server and curl and are not bootstrap dependencies.
The optional HTTP builtin's implementation is not a pure-.sa HTTP/TLS stack.

## Offline list algorithms (2026-10-16)

Four real `.sa` helpers extend the existing standalone `list_algo` module:

| Helper | Contract | Cost |
|---|---|---|
| `la_lower_bound(xs, v)` | First index with value >= v, or `len(xs)` | O(log n) comparisons |
| `la_upper_bound(xs, v)` | First index with value > v, or `len(xs)` | O(log n) comparisons |
| `la_merge_sorted(a, b)` | Fresh sorted merge, retains duplicates; equal values taken from a first | O(n + m) elements |
| `la_rotate(xs, shift)` | Fresh left rotation; negative shifts rotate right; reduced modulo length | O(n) elements |

Bounds and merge require ascending sorted input with finite numeric values;
there is no sortedness validation or NaN/Infinity total-order promise. Bound
indices are insertion positions in `[0, len(xs)]`, not -1 sentinels. Merge
accepts empty lists and aliased inputs. Rotation requires integer shifts within
the runtime's signed-integer modulo range; empty input avoids modulo zero.
Fresh results never alias an input, including zero rotations and empty-side
merges. No helper changes input elements or list length.

`make test-stdlib-list-search` requires **all three** seed-min/Gen2/native
backends (no native skip), compiles C with strict pointer/prototype diagnostics,
and checks exact output against an independent expected success marker. The
fixture checks explicit bound positions plus a small-domain linear oracle,
duplicates, missing endpoints, negative values, empty/singleton inputs, merge
contents, negative/wrapped shifts, and input preservation after result pushes.
The gate is included by `test-stdlib-modules` (therefore `test-stdlib` and
`test-stdlib-growth`) and `native-test`. Existing module/JSON fixtures remain.
Logs: [2026-10-16 offline stdlib](gate-logs/2026-10-16-stdlib/).

### Explicit non-goals

This remains a **small utility library, not a full standard library**. No
JSON printer for nested values, Unicode text model,
heterogeneous lists, filesystem metadata API or pure-.sa HTTP/TLS stack is
added. `json_util` remains flat and non-validating; `f_exists`
means readable **and nonempty**, not filesystem existence (empty/missing files
are indistinguishable there). `t_hash` is non-cryptographic. HTTP/network
examples and their optional dependencies stay outside required bootstrap gates.
The new module code and tests use no network or interpreter dependency.

Two items left this list on 2026-10-22: nested JSON *reading*
(`stdlib/json_deep.sa`) and cryptographic hashing (`stdlib/crypto.sa`). Writing
nested JSON is still not provided, and the non-goals above are otherwise
unchanged.

## Nested JSON and cryptography (2026-10-22)

Two modules, both written in the dialect all three backends accept, both
checked on all three backends by their own gate.

### `stdlib/json_deep.sa` -- reading nested JSON

`jd_*` reads a value at a **path**: `"user.name"`, `"items.2.id"`,
`"a.b.0.1.c"`. Reader helpers: `jd_valid` (whole-document check), `jd_type`
(`object`/`array`/`string`/`number`/`bool`/`null`/`none`), `jd_has`, `jd_raw`
(the exact source slice of the value), `jd_text` (a string value, escapes
decoded, `\uXXXX` folded to UTF-8), `jd_num`, `jd_flag`, `jd_len` (members of
an object, elements of an array, bytes of a string) and `jd_key` (the i-th key
of an object, for walking a document whose keys are not known in advance).

What it refuses is as pinned as what it accepts: `test-stdlib-json-deep`
checks 8 accepted documents (including `null`, `-0.5e+10`, `[]`, `{}` and
`[[[[1]]]]`) and **15 refusals** -- empty input, a trailing comma in an object
and in an array, an unterminated array, a missing colon, an unquoted key,
trailing text after a complete value, the numbers `01`, `1.` and `1e`, a
missing value after a colon, the truncated literal `tru`, an unknown `\x`
escape, and the mismatched closers `[1}` and `{"a":1}}`. The same gate feeds flat objects
through both `json_util.sa` and `json_deep.sa` and requires the two to agree,
so the new module cannot drift away from the old one on the cases both cover.

`jd_set_raw(doc, path, raw_val)` replaces an **existing** value at a path,
including the root (empty path). Both the document and replacement must be
complete valid JSON; invalid inputs or a missing path return the empty string.
It preserves surrounding source bytes and exact number text, uses the reader's
first-duplicate-key and raw-key matching rules, and does not create missing
members or array elements. `jd_delete_raw` removes an existing non-root
value, returning an empty string for invalid input or a missing path.
`jd_object_put_raw` inserts or replaces a member in an existing object at a
parent path; its key is a complete JSON string and matches by raw escape
spelling. Both operations preserve unrelated bytes and do not create missing
containers. `jd_object_ensure_raw` sets an object-only dotted path and creates
missing intermediate objects. It refuses traversal through existing arrays or
scalars, validates raw JSON key spellings, and replaces the root for an empty
path. `jd_array_insert_raw(doc, parent_path, index, raw_val)` inserts
before an integer index or appends at the array length; invalid JSON, a missing
or non-array parent, and fractional or out-of-range indexes return the empty
string. Keys containing dots cannot be addressed by path, but can be
inserted with `jd_object_put_raw`. For pretty-printing see `json_write.sa`.
`jd_num` still converts to an IEEE double; use `jd_raw` for exact number text.

### `stdlib/crypto.sa` -- SHA-256 and HMAC-SHA256

`cx_sha256(text)` and `cx_hmac(key, text)` answer lower-case hex; the `_list`
forms take byte lists, so data that is not valid text (or that contains a zero
byte, which a Sayanox string cannot carry) still hashes; the `_raw` forms
answer a byte list. `cx_hex`, `cx_hex_byte`, `cx_unhex` and `cx_bytes` convert
between the three representations, and `cx_eq_hex` compares two digests
without caring about letter case.

The implementation is pure arithmetic: the dialect the seed accepts has no
bitwise operators, so the 32-bit words are carried as numbers and the
rotations, shifts, `and`, `or`, `xor` and `not` of the algorithm are done with
division and remainder. That is slower than a `uint32_t` implementation and it
is the price of running on all three backends.

`test-stdlib-crypto` checks the FIPS 180-4 vectors (empty string, `abc`, the
two-block message), the padding boundaries at 55, 56, 63, 64 and 65 bytes, RFC
4231 HMAC cases 1, 2 and 3, hex round-trips, the nine bit primitives, and a
tamper fixture where one flipped byte must change the digest. When `sha256sum`
is installed the gate also compares against it; when it is not, that one check
prints `[SKIP]` and the rest still runs, because no bootstrap gate may depend
on a tool outside the minimal set.

This module provides SHA-256 and HMAC-SHA256 primitives (`tools/sxpkg` uses it
for package digests and symmetric keyed signatures). Asymmetric signatures live
in `stdlib/pubkey.sa` below.

### `stdlib/pubkey.sa` -- Curve25519 Schnorr-SHA256 public-key signatures

`stdlib/pubkey.sa` implements portable pure-Sayanox asymmetric key derivation,
deterministic Schnorr signing, and public-key-only verification on the twisted
Edwards curve `-x^2 + y^2 = 1 + d*x^2*y^2` over `GF(2^255 - 19)` using the
RFC 8032 Ed25519 basepoint `B` and prime subgroup order `L`:

* `pk_seed_from_passphrase(pass)` / `pk_pubkey(seed_hex)` / `pk_keyid(pub_hex)`
* `pk_sign(seed_hex, msg)` -> 128-hex `(R || S)` deterministic signature
* `pk_verify(pub_hex, msg, sig_hex)` -> `1` iff `S < L`, `A` and `R` decode to
  canonical curve points, and `[8*S]B == [8]R + [8*e]A` (never touches the
  secret seed)

`make test-sxpkg-pubkey` pins 3-way native parity (`seed-min == gen2 == native_aot`)
on `selfhost/stdlib_pubkey_test.sa` plus end-to-end `sxpkg` package (`pubsig=`)
and index (`INDEX.sig`) verification with `.sec` deleted. Arithmetic uses 16-bit
limbs inside IEEE-754 doubles (exact below `2^53`), with no constant-time
side-channel claim.


## `csv.sa`: CSV rows without string lists (2026-10-26)

The dialect refuses string-valued list elements, so a parsed CSV row cannot be
a `list` of `str`. `csv.sa` uses the same trick as `cli.sa`: a **packed string**
where every field is stored as its decimal byte length, a colon, and the raw
bytes (`3:abc0:` holds `abc` and the empty field). `csv_parse_row` returns that
packed form; `csv_ok`, `csv_count`, `csv_at`, `csv_push` and `csv_empty` are the
operations on it, and `csv_write_row` turns it back into a CSV record.

* `csv_parse_row` handles one record (no trailing newline). A quoted field may
  contain commas, CR, LF and doubled quote characters. A quote inside an
  unquoted field, an unclosed quoted field, or any byte other than a comma
  after a closing quote makes the row invalid: the result is the single-byte
  error marker `chr(33)`, which `csv_ok` rejects and `csv_count` reads as zero.
  An empty line is one empty field; a trailing comma makes one more.
* `csv_write_row` quotes a field only when it contains a comma, a quote, CR or
  LF, and doubles every quote inside it. Quote characters are always built
  with `chr(34)` so no source line needs an escape.
* Strings stay byte strings. A UTF-8 rune is several bytes and is preserved as
  several bytes; this is not a Unicode-aware CSV implementation.
* Gate: `make test-stdlib-csv` pins 44 hand-computed values from
  `selfhost/stdlib_csv_test.sa` on seed-min and gen2, requires native_aot to
  produce byte-identical stdout, checks that the module stands alone, and
  checks that its `csv_` prefix coexists with `stdlib/str_text.sa`'s `t_`
  helpers.


## The 2026-10-26 batch: `url.sa`, `datetime.sa`, `hash.sa`

Three more portable modules, one gate (`make test-stdlib-next`). Their expected
output is **not** produced by running Sayanox: `selfhost/stdlib_url.want`,
`selfhost/stdlib_datetime.want` and `selfhost/stdlib_hash.want` were computed
independently with host Python standard libraries (`urllib.parse`,
`datetime`/`calendar`, `zlib`) plus hand-written rolling-hash and Luhn oracles.
The gate requires seed-min, gen2 and native_aot to reproduce all 106 lines
byte-for-byte, and also checks that each module stands alone and that the
`csv_` / `surl_` / `dt_` / `sh_` prefixes coexist in one spliced program.

* **`url.sa` (`surl_`)** — `surl_encode` percent-encodes every byte outside
  `A-Z a-z 0-9 - . _ ~` as uppercase `%XX`. `surl_decode_ok` rejects a stray
  percent sign or a non-hex escape, and `surl_decode` returns an empty string
  in that case. `%00` is refused too: strings are C strings, so a NUL byte
  would silently truncate. A query is a packed string of alternating
  length-prefixed key/value fields (same trick as `cli.sa` and `csv.sa`),
  because the dialect refuses string-valued list elements. `surl_query_parse`
  splits on `&` and the first `=`, decodes both sides, and refuses the whole
  query on one bad escape; `surl_query_write` re-encodes and rejoins it.

* **`datetime.sa` (`dt_`)** — proleptic Gregorian, years 1..9999. `dt_jdn`
  is the Julian Day Number; `dt_from_jdn` inverts it by binary search over
  years and a linear scan over months that call `dt_jdn` itself, so the inverse
  cannot drift from the forward conversion. Weekdays are `0 = Monday ..
  6 = Sunday`. Invalid dates return documented sentinels (`-1`, `[0,0,0]` or
  the empty string) instead of a guess. No floating-point transcendental
  functions and no platform date APIs are involved.

* **`hash.sa` (`sh_`)** — checksums only, **not cryptographic**; use
  `stdlib/crypto.sa` for SHA-256/HMAC. `sh_poly` is a rolling hash modulo the
  31-bit prime 2147483647, which keeps every product below 2^53 so a C double
  holds each step exactly. `sh_adler32` is RFC 1950 Adler-32 as one number
  (`B * 65536 + A`). `sh_luhn_check_digit` computes a Luhn check digit for an
  all-digit payload and `sh_luhn_valid` validates a complete number; both
  refuse non-digit input.
