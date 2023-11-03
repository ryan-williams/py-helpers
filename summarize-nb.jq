# Process a Jupyter notebook file by eliding "outputs".
#
# Elements of the ".outputs" array have their values replaced with objects like:
#
# ```json
#   "outputs": [
#     {
#       "data": {
#         {
#           "image/png": {
#             "top5": "iVBOR",
#             "length": 79784
#           },
#           "text/html": {
#             "top5": [
#               "<style type=\"text/css\">\n",
#               "</style>\n",
#               "<table id=\"T_26670\" style='display:inline'>\n",
#               "  <caption>Missing in 0</caption>\n",
#               "  <thead>\n"
#             ],
#             "length": 267877,
#             "totalLength": 17184179
#           },
#           "text/plain": {
#             "top5": [
#               "<IPython.core.display.HTML object>"
#             ],
#             "length": 1,
#             "totalLength": 34
#           }
#         }
#       }
#     }
#   ],
# ```
#
# Above we have three outputs (combined from two adjacent cells in Analysis.ipynb):
# - 79KB "image/png",
# - 17MB(!) "text/html" (as an array of 267,877 line-strings)
# - 34B "text/plain"

.cells
| map(
    .outputs = (
        (.outputs // [])
        | map(.data = (
            (.data // {})
            | with_entries(
                .value = (
                    .value
                    | (
                        {
                            top5: .[:5],
                            length: . | length,
                        } + (
                            if type == "array" then
                                { totalLength: . | map(length) | add }
                            else
                                {}
                            end
                        )
                    )
                )
            )
        ))
    )
)[]
