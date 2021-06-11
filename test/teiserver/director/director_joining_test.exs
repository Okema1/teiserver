defmodule Teiserver.Protocols.Director.JoiningTest do
  use Central.ServerCase, async: false
  alias Teiserver.TeiserverTestLib
  alias Teiserver.Battle.BattleLobby
  alias Teiserver.Common.PubsubListener
  alias Teiserver.Director

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  @sleep 50

  setup do
    Teiserver.Director.start_director()
    %{socket: socket, user: user, pid: pid} = tachyon_auth_setup()

    battle_data = %{
      cmd: "c.battle.create",
      name: "Director #{:random.uniform(999_999_999)}",
      nattype: "none",
      port: 1234,
      game_hash: "string_of_characters",
      map_hash: "string_of_characters",
      map_name: "koom valley",
      game_name: "BAR",
      engine_name: "spring-105",
      engine_version: "105.1.2.3",
      settings: %{
        max_players: 12
      }
    }
    data = %{cmd: "c.battle.create", battle: battle_data}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    battle_id = reply["battle"]["id"]

    BattleLobby.start_director_mode(battle_id)
    consul_pid = BattleLobby.get_battle!(battle_id).consul_pid
    listener = PubsubListener.new_listener(["battle_updates:#{battle_id}"])

    {:ok, socket: socket, user: user, pid: pid, battle_id: battle_id, listener: listener, consul_pid: consul_pid}
  end

  test "welcome message", %{socket: socket, user: user, battle_id: battle_id, listener: listener, consul_pid: consul_pid} do
    consul_state = GenServer.call(consul_pid, :get_all)
    assert consul_state.welcome_message == nil

    data = %{cmd: "c.battle.message", userid: user.id, message: "!welcome-message This is the welcome message"}
    _tachyon_send(socket, data)

    # msg = "!welcome-message This is the welcome message"
    # BattleLobby.say(user.id, msg, battle_id)

    messages = PubsubListener.get(listener)
    assert messages == []

    consul_state = GenServer.call(consul_pid, :get_all)
    assert consul_state.welcome_message == "This is the welcome message"

    # Now a new user joins the battle
    %{socket: socket2, user: user2, pid: pid2} = tachyon_auth_setup()
    data = %{cmd: "c.battle.join", battle_id: battle_id}
    _tachyon_send(socket2, data)

    reply = _tachyon_recv(socket2)
    assert reply == %{
      "cmd" => "s.battle.join",
      "result" => "waiting_for_host"
    }

    # Accept them
    data = %{cmd: "c.battle.respond_to_join_request", userid: user2.id, response: "approve"}
    _tachyon_send(socket, data)
    _battle = _tachyon_recv(socket2)

    # Expect director mode announcement
    reply = _tachyon_recv(socket2)
    assert reply == %{
      "cmd" => "s.battle.announce",
      "message" => "Director mode enabled",
      "sender" => user.id
    }

    # Expect welcome message
    reply = _tachyon_recv(socket2)
    assert reply == %{
      "cmd" => "s.battle.announce",
      "message" => "This is the welcome message",
      "sender" => Director.get_coordinator_userid()
    }
  end
end