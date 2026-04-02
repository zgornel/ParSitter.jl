using AbstractTrees, EzXML
using Revise
using ParSitter

_R_file = (ParSitter.File(abspath(expanduser("~/vub/code/aivet/notes/extracted_code.r"))), "r")
_R_code = (
    ParSitter.Code(
        """
        mod13 <- glmmTMB(Center_ownership ~ Gender + Nationality + Income_quintile +
                                           P80P20 + Study_degree + ISCED_origin + Year +
                                           (1 | Family),
                                  data = practiques,
                                  family = binomial(link = "linear"))
        """
    ), "r",
)
#_parsed = ParSitter.parse(_PYTHON...)
#_parsed = ParSitter.parse(_C...)
_parsed = ParSitter.parse(_R_code...)
target = ParSitter.build_xml_tree(_parsed)

query = ParSitter.build_tq_tree(
    (
        "*",
        "glmmTMB",                      # -> glmmTMB
        (
            "*",                          # -> (...)
            (
                "*",                       # -> family = binomial(link=...)
                "family",               # -> family
                (
                    "*",                      # -> binomial(link=...)
                    "@family",            # -> binomial
                    (
                        "*",                   # -> argument
                        (
                            "*",
                            "@identifier",
                            (
                                "*",
                                "@string",
                            ),
                        ),
                    ),
                ),
            ),
        ),
    )
)     # -> link=(...)

# Query helper functions
#_target_nodevalue(n) = strip(string(n.name))
_target_nodevalue(n) = strip(replace(n.content, r"[\s]" => ""))
_query_nodevalue(n) = ifelse(ParSitter.is_capture_node(n).is_match, string(split(n.head, "@")[1]), n.head)
_apply_regex_glob(tn, qn) = ParSitter.is_capture_node(qn; capture_sym = "@").is_match || qn.head == "*"
_capture_function(n) = (v = strip(replace(n.content, r"[\s]" => "")), srow = n["srow"], erow = n["erow"], scol = n["scol"], ecol = n["ecol"])


RULES = [
    (name = "glmmTMB binomial logit link type", query = query, type = "acceptable", check_for = Dict("family" => "binomial", "identifier" => "link", "string" => "logit")),
    (name = "glmmTMB gaussian logit link type", query = query, type = "acceptable", check_for = Dict("family" => "gaussian", "identifier" => "link", "string" => "logit")),
]
apply_rules(code_tree, rules) = begin
    for r in rules
        query = ParSitter.build_tq_tree(r.query)
        query_results = ParSitter.query(
            target.root, query;
            match_type = :nonstrict,
            target_tree_nodevalue = _target_nodevalue,
            query_tree_nodevalue = _query_nodevalue,
            capture_function = _capture_function,
            node_comparison_yields_true = _apply_regex_glob
        )
        filter!(first, query_results) # keep only matches
        # for each query result captures, check that the keys in 'check_for' Dict
        # of the rule are found among the captured symbols of the tree matcher
        for qr in query_results
            for (k, v) in r.check_for
                for (qr_k, qr_v) in qr[2]
                    for (qr_vi, srow, _, scol, _) in qr_v
                        if r.type == "acceptable"
                            #check that if qr_k ==k ⟹  qr_v == v
                            #TODO: Implement a formula template to apply the values to.
                            if (qr_k == k) && !(qr_vi == v)
                                @warn "$(r.name): expected value '$v', got in code '$(qr_vi)'  row=$(srow), col=$(scol)"
                            end
                        end
                    end
                end
            end
        end
    end
end
apply_rules(_R_code, RULES)
