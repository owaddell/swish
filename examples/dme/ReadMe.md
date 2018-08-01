## Extending Pattern Matching

The examples in this directory show how to extend the match pattern language
using `define-match-extension`.

| Example | Shows how to |
|---------|-------------|
| [condition](condition.ss) | match conditions, e.g., native exceptions |
| [condition tests](condition.ms) | use condition patterns to match native exceptions |
| [ht](ht.ss) | match functional hash tables |
| [ht tests](ht.ms) | use functional hash table patterns |
| [json](json.ss) | match JSON objects |
| [json tests](json.ms) | use JSON patterns |
| [re](re.ss) | match regular expressions |
| [re tests](re.ms) | use regular expression patterns |

### Limitations

There is presently no way for transformers to examine the patterns of multiple match clauses simultaneously.

The `handle-object` and `handle-field` procedures provided to `define-match-extension` cannot access the compile-time environment directly. They may be able to generate output containing macros that do that sort of lookup, but this may not be adequate for some kinds of transformations.
