.cells = (
    .cells | map(
        .metadata.slideshow.slide_type |= (
            if . == "" then "skip" else (. // "skip") end
        )
    )
)
