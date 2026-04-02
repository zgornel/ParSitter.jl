using AbstractTrees
using Revise
using ParSitter
query_snippet = """
        {{::IDENTIFIER}} <- glmmTMB({{::R_FORMULA}},
                                  family ={{family::IDENTIFIER}}({{identifier::IDENTIFIER}} = {{id_val::STRING}}))
"""
language = "r"
query_expr = ParSitter.QueryLanguage.parse_code_snippet_to_query(query_snippet, language);
print_tree(query_expr; maxdepth = 10)
