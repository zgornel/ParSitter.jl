# Walk test/languages, run tests in files there
language_test_directory = joinpath(dirname(abspath(@__FILE__)), "languages")
for (root, _, files) in walkdir(language_test_directory)
    for file in files
        full_file = joinpath(language_test_directory, file)
        include(full_file)
    end
end
