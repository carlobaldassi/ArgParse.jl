# test 3: dest_name, metavar, range_tester, alternative
#         actions

using ArgParse
using Base.Test

function ap_test3(args)

    s = ArgParseSettings("Test 3 for ArgParse.jl")

    @add_arg_table s begin
        "--opt1"
            action = :append_const   # appends 'constant' to 'dest_name'
            arg_type = String
            constant = "O1"
            dest_name = "O_stack"    # this changes the destination
            help = "append O1"
        "--opt2"
            action = :append_const
            arg_type = String
            constant = "O2"
            dest_name = "O_stack"    # same dest_name as opt1, different constant
            help = "append O2"
        "-k"
            action = :store_const    # stores constant if given, default otherwise
            default = 0
            constant = 42
            help = "provide the answer"
        "--awkward-option"
            nargs = '+'                         # eats up as many argument as found (at least 1)
            action = :append_arg                # argument chunks are appended when the option is
                                                # called repeatedly
            dest_name = "awk"
            range_tester = (x->x=="X"||x=="Y")  # each argument must be either "X" or "Y"
            metavar = "XY"
            help = "either X or Y; all XY's are " *
                   "stored in chunks"
    end

    s.exc_handler = (settings, err)->error(err.text)

    parsed_args = parse_args(args, s)
end

@test ap_test3([]) == (String=>Any)["O_stack"=>String[], "k"=>0, "awk"=>Vector{Any}[]]
@test ap_test3(["--opt1", "--awk", "X", "X", "--opt2", "--opt2", "-k", "--awkward-option=Y", "X", "--opt1"]) ==
    (String=>Any)["O_stack"=>String["O1", "O2", "O2", "O1"], "k"=>42, "awk"=>{{"X", "X"}, {"Y", "X"}}]
@test_throws ap_test3(["X"])
@test_throws ap_test3(["--awk", "Z"])
