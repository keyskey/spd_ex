defmodule SpdEx do
  @moduledoc """
  Multi-agent simulation code for Spatial Prisoners Dilemma Game.
  """
  @c  1
  @d  0
  @n  1000
  @average_degree 8
  @time  100

  @doc """
    Main function
  """
  def main do
    File.write "output.csv", "Dg, Dr, Fc \n"
    init_cid = Enum.take_random( 0..@n, div(@n, 2) )                     # Half of the entire population is initially cooperative
    dilemma_range = Enum.map 1..10, fn(number) -> number * 0.1 end       # return [0, 0.1, 0.2, ..., 1.0]
    init_fc = length(init_cid)/@n                                        # Initial Fc should be 0.5

    Enum.map dilemma_range, fn(dg) ->
      Enum.map dilemma_range, fn(dr) ->
        %SpdEx.Result{agents: generate_agents(@n), dg: dg, dr: dr, fc: [init_fc]}
        |> init_strategy(init_cid)
        |> link_agents
        |> timestep(0)          # Go to recursive loop  
      end
    end
  end

  @doc """
    Time evolution loop. The entire procedure is as follows;
    1. Agents get payoff
    2. Decide the next strategy based on PW-Fermi
    3. Update strategy
    4. Count the fraction of cooperators
    5. Check whether converged or not
    6. If converged, stop the calculation with a given dilemma setting. If not, go to the next timestep.
  """
  def timestep(%SpdEx.Result{dg: dg, dr: dr, fc: fc_list} = result, time) do
    if time == 0 do
      IO.puts "Initial condition, Dg: #{Float.floor(dg, 1)}, Dr: #{Float.floor(dr, 1)}, Fc: #{Float.floor(hd(fc_list), 2)}"
    end

    %SpdEx.Result{agents: new_agent_list} = result |> payoff |> im_update |> update_strategy  
    fc = new_agent_list |> get_fraction
    new_fc_list = [fc] ++ fc_list
    new_result = %SpdEx.Result{result | agents: new_agent_list, fc: new_fc_list}
    IO.puts "Dg: #{Float.floor(dg, 1)}, Dr: #{Float.floor(dr, 1)}, Time: #{time}, Fc: #{Float.floor(fc, 2)}"

    # Check if Fc is converged or not.
    if converged?(new_fc_list) or time == @time do
      write_to_csv(new_result)
    else
      timestep(new_result, time + 1)
    end
  end

  @doc """
    Write the fraction of cooperators to csv file
  """
  def write_to_csv(%SpdEx.Result{dg: dg, dr: dr, fc: [head | _tail] }) do
    File.write "output.csv", "#{Float.floor(dg, 1)}, #{Float.floor(dr, 1)}, #{Float.floor(head, 2)} \n", [:append]
  end

  @doc """
    Check whether the calculation is converged or not.
  """
  def converged?([head | _tail] = fc_list) do
    cond do
      # Convergence condition
      head in [0, 1] -> true
      abs(Statistics.mean(Enum.slice(fc_list, 0, 99)) - head) < 0.01 -> true

      # If not converged
      true -> false
    end
  end

  @doc """
    Return fraction of cooepartors
  """
  def get_fraction(agent_list) do
    num_c = Enum.filter(agent_list, fn(%SpdEx.Agent{strategy: strategy}) -> strategy == @c end) |> length
    num_c/@n
  end

  @doc """
    Insert next strategy into current strategy
  """
  def update_strategy(%SpdEx.Result{agents: agent_list} = result) do
    after_update = Enum.map agent_list, fn(%SpdEx.Agent{next_strategy: next_strategy} = focal) -> %SpdEx.Agent{focal | strategy: next_strategy} end

    %SpdEx.Result{result | agents: after_update}
  end

  @doc """
    Decide the next strategy by PW-Fermi rule
  """
  def pf_update(%SpdEx.Result{agents: agent_list} = result) do
    after_pf = Enum.map agent_list, fn(%SpdEx.Agent{neighbors_id: neighbors_id, strategy: focal_strategy, point: focal_point} = focal) ->

      # Get neighbors of focal agent
      neighbors = Enum.filter agent_list, fn(%SpdEx.Agent{id: agent_id}) -> agent_id in neighbors_id end

      # Randomely choose game opponent from neighbors and get his point & strategy
      %SpdEx.Agent{point: opp_point, strategy: opp_strategy} = Enum.random(neighbors)

      # Pairwise comparison
      if :rand.uniform < 1/(1 + :math.exp((focal_point - opp_point)/0.1)) do
        %SpdEx.Agent{focal | next_strategy: opp_strategy}      # Change strategy
      else
        %SpdEx.Agent{focal | next_strategy: focal_strategy}    # Keep the same strategy
      end
    end

    %SpdEx.Result{result | agents: after_pf}
  end

  @doc """
    Decide the next strategy by Imitation-Max rule
  """
  def im_update(%SpdEx.Result{agents: agent_list} = result) do
    after_im = Enum.map agent_list, fn(%SpdEx.Agent{neighbors_id: neighbors_id, strategy: focal_strategy, point: focal_point} = focal) ->

      # Get neighbors of focal agent
      neighbors = Enum.filter agent_list, fn(%SpdEx.Agent{id: agent_id}) -> agent_id in neighbors_id end

      max_point = neighbors
      |> Enum.map(fn(%SpdEx.Agent{point: neighbor_point}) -> neighbor_point end)
      |> Enum.max

      if max_point > focal_point do
        [%SpdEx.Agent{strategy: best_strategy} | _tail] = Enum.filter neighbors, fn(%SpdEx.Agent{point: point}) -> point == max_point end
        %SpdEx.Agent{focal | next_strategy: best_strategy}      # Change strategy
      else
        %SpdEx.Agent{focal | next_strategy: focal_strategy}     # Keep the same strategy
      end
    end

    %SpdEx.Result{result | agents: after_im}
  end

  @doc """
    Count payoff obtained in one timestep
  """
  def payoff(%SpdEx.Result{dg: dg, dr: dr, agents: agent_list} = result) do
    after_payoff = Enum.map agent_list, fn(%SpdEx.Agent{neighbors_id: neighbors_id, strategy: focal_strategy, point: _point} = focal) ->

      # Get neighbors of focal agent
      neighbors = Enum.filter(agent_list, fn(%SpdEx.Agent{id: agent_id}) -> agent_id in neighbors_id end)

      # Store payoff obtained in the game with each neighbor in a list
      total_point = Enum.map(neighbors, fn(%SpdEx.Agent{strategy: neighbor_strategy}) ->
          cond do
            neighbor_strategy == @c and focal_strategy == @c -> 1
            neighbor_strategy == @c and focal_strategy == @d -> 1+dg
            neighbor_strategy == @d and focal_strategy == @c -> -dr
            neighbor_strategy == @d and focal_strategy == @d -> 0
          end
        end)
        |> Enum.sum

      %SpdEx.Agent{focal | point: total_point}
    end

    %SpdEx.Result{result | agents: after_payoff}
  end

  @doc """
    Add neighbors to all agents.
    Only neighbor's id is provided to focal agents. 
  """
  def link_agents(%SpdEx.Result{agents: agent_list} = result) do
    agents_with_neighbors_id = Enum.map agent_list, fn(%SpdEx.Agent{id: focal_id} = agent) ->
    
      # Neighbors are chosen from the entire population, except for focal itself.
      # Current version just assuming random graph for its simplicity, but other network topology will added in the future...
      neighbors_id = 1..@n |> Enum.to_list |> List.delete(focal_id) |> Enum.take_random(@average_degree)

      %SpdEx.Agent{agent | neighbors_id: neighbors_id}
    end

    %SpdEx.Result{result | agents: agents_with_neighbors_id}
  end

  @doc """
    Set initial cooperators
  """
  def init_strategy(%SpdEx.Result{agents: agent_list} = result, init_cid) do
    initialized_agent = Enum.map agent_list, fn(%SpdEx.Agent{id: id} = agent) ->
      if id in init_cid do
        %SpdEx.Agent{agent | strategy: @c}
      else
        %SpdEx.Agent{agent | strategy: @d}
      end
    end

    %SpdEx.Result{result | agents: initialized_agent}
  end

  @doc """
    Generate n agents with continuous ID from 1 to n
  """
  def generate_agents(n) do
    Enum.map 1..n, fn(id) -> %SpdEx.Agent{id: id} end
  end
end
