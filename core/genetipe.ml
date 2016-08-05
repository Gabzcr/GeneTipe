let () =
    let pop_size = ref None in
    let max_depth = ref None in
    let generations = ref 100 in
    let verbosity = ref 2 in
    let show_graph = ref false in
    let config_filename = ref "" in

    let spec_list =
    [
        ("--pop", Arg.Int (function p -> pop_size := Some p), "Set the population size (override the config file)");
        ("-p", Arg.Int (function p -> pop_size := Some p), "Shorthand for --pop");
        ("--gen", Arg.Set_int generations, "Set the number of generations (default is 100)");
        ("-g", Arg.Set_int generations, "Shorthand for --gen");
        ("--depth", Arg.Int (function d -> max_depth := Some d), "Set the maximum depth of an individual (override the config file)");
        ("-d", Arg.Int (function d -> max_depth := Some d), "Shorthand for --depth");
        ("--rand", Arg.Int (function r -> Random.init r), "Set the random seed");
        ("-r", Arg.Int (function r -> Random.init r), "Shorthand for --rand");
        ("--quiet", Arg.Unit (fun () -> verbosity := 0), "Do not show anything else than the result (equivalent to -v 0)");
        ("--no-stats", Arg.Unit (fun () -> verbosity := 1), "No intermediate statistics about the currently generated population (equivalent to -v 1)");
        ("--full-stats", Arg.Unit (fun () -> verbosity := 3), "Print full statistics about the currently generated population (equivalent to -v 3)");
        ("-v", Arg.Set_int verbosity, "Set the verbosity level (default is 2). Lower values speed up the process");
        ("--graph", Arg.Set show_graph, "Show a graph with the point set and the best computed function at the end")
    ]
    in

    let usage_msg =
        "GeneTipe is a symbolic regression tool.\n" ^
        "It automatically build a function matching the points given using a genetic algorithm.\n" ^
        "The program waits as input the number of sampling points on the first line and then on each line the x and y coordinates of a point separated by a space.\n"^
        "Usage : genetipe [options] configFilename\n\n" ^
        "Options available:"
    in

    Arg.parse spec_list (fun cfg_file -> config_filename := cfg_file) usage_msg;
    if !config_filename = "" then raise (Arg.Bad "No config file given");

    ParamReader.read ?pop_size:!pop_size ?max_depth:!max_depth ~filename:!config_filename;
    let module Parameters = (val ParamReader.get_evolution_params ()) in
    let module CurrentEvolver = Evolver.Make (Parameters) in
    let module StatsPrinter = Stats.MakePrinter (Parameters.Individual) in

    let nb_points = Scanf.scanf "%d\n" (function n -> n) in
    let points = Array.make nb_points (0.,0.) in
    for i = 0 to nb_points-1 do
        points.(i) <- Scanf.scanf "%f %f\n" (fun x y -> (x,y))
    done;

    if !verbosity >= 1 then Printf.printf "Initialize the population with %d individuals\n" Parameters.pop_size;
    let init_pop = CurrentEvolver.init_population () in
    let pop = ref (CurrentEvolver.compute_fitness points init_pop) in
    if !verbosity >= 1 then StatsPrinter.print_population !pop;

    Sys.catch_break true; (* If you do a Ctrl+C you still have the results *)
    (try
        for g = 1 to !generations do
            if !verbosity >= 1 then Printf.printf "- Generation %d -\n%!" g;
            pop := CurrentEvolver.evolve points !pop;
            if !verbosity >= 2 then StatsPrinter.print_stats !pop;
            (*if !verbosity >= 3 then StatsPrinter.print_advanced_stats !pop*)
        done
    with Sys.Break -> ());

    pop := CurrentEvolver.simplify_individuals !pop;
    if !verbosity >= 1 then
    (
        Printf.printf "= End of evolution =\n";
        StatsPrinter.print_population !pop;
        Printf.printf "= Final stats =\n";
        StatsPrinter.print_stats !pop;
        (*StatsPrinter.print_advanced_stats !pop*)
    )
    else
    (
        let bestFitness, bestDna = Stats.best_individual !pop in
        Printf.printf "%f\n%s" bestFitness (Parameters.Individual.to_string bestDna)
    );

    (*if !show_graph then
    (
        Printf.printf "%!";

        try
            let graph = Plot.init ~size:(600,600) ~border:25 ~title:"GeneTipe" in
            Plot.plot ~color:Graphics.red ~link:false (Array.map fst points) (Array.map snd points) graph;
            Plot.plot_fun ~color:Graphics.blue ~nb_pts:(nb_points*10) (!pop |> Stats.best_individual |> snd |> Dna.eval) graph;
            Plot.show graph;
            Graphics.loop_at_exit [] (fun _ -> ())
        with Graphics.Graphic_failure _ -> ()
    )*)
;;
