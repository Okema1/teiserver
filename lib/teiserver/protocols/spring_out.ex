defmodule Teiserver.Protocols.SpringOut do
  @moduledoc """
  Out component of the Spring protocol.

  Protocol definition:
  https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html
  """
  require Logger
  alias Teiserver.Client
  alias Teiserver.Battle
  alias Teiserver.Room
  alias Teiserver.User
  alias Teiserver.TcpServer
  alias Teiserver.Protocols.SpringLib

  @motd """
  Message of the day
  Welcome to Teiserver
  Connect on port 8201 for TLS
  ---------
  """

  @spec reply(atom(), nil | String.t() | tuple() | list(), String.t(), map) :: map
  def reply(reply_cmd, data, msg_id, state) do
    msg = do_reply(reply_cmd, data)
    _send(msg, msg_id, state)
    state
  end

  @spec do_reply(atom(), String.t() | list()) :: String.t() | List.t()
  defp do_reply(:login_accepted, user) do
    "ACCEPTED #{user}\n"
  end

  defp do_reply(:denied, reason) do
    "DENIED #{reason}\n"
  end

  defp do_reply(:motd, nil) do
    @motd
    |> String.split("\n")
    |> Enum.map(fn m -> "MOTD #{m}\n" end)
    |> Enum.join("")
  end

  defp do_reply(:welcome, nil) do
    "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"
  end

  defp do_reply(:pong, nil) do
    "PONG\n"
  end

  defp do_reply(:login_end, nil) do
    "LOGININFOEND\n"
  end

  defp do_reply(:agreement, nil) do
    [
      "AGREEMENT A verification code has been sent to your email address. Please read our terms of service and then enter your six digit code below.\n",
      "AGREEMENT \n",
      "AGREEMENTEND\n"
    ]
  end

  defp do_reply(:okay, cmd) do
    if cmd do
      "OK cmd=#{cmd}\n"
    else
      "OK\n"
    end
  end

  defp do_reply(:list_battles, battle_ids) do
    ids = battle_ids
    |> Enum.join(" ")
    "BATTLEIDS #{ids}\n"
  end

  defp do_reply(:add_user, user) do
    "ADDUSER #{user.name} #{user.country} 0 #{user.id} #{user.lobbyid}\n"
  end

  defp do_reply(:remove_user, {_userid, username}) do
    "REMOVEUSER #{username}\n"
  end

  defp do_reply(:friendlist, user) do
    friends =
      user.friends
      |> Enum.map(fn f ->
        name = User.get_username(f)
        "FRIENDLIST userName=#{name}\n"
      end)

    (["FRIENDLISTBEGIN\n"] ++ friends ++ ["FRIENDLISTEND\n"])
    |> Enum.join("")
  end

  defp do_reply(:friendlist_request, user) do
    requests =
      user.friend_requests
      |> Enum.map(fn f ->
        name = User.get_username(f)
        "FRIENDREQUESTLIST userName=#{name}\n"
      end)

    (["FRIENDREQUESTLISTBEGIN\n"] ++ requests ++ ["FRIENDREQUESTLISTEND\n"])
    |> Enum.join("")
  end

  defp do_reply(:ignorelist, user) do
    ignored =
      user.ignored
      |> Enum.map(fn f ->
        name = User.get_username(f)
        "IGNORELIST userName=#{name}\n"
      end)

    (["IGNORELISTBEGIN\n"] ++ ignored ++ ["IGNORELISTEND\n"])
    |> Enum.join("")
  end

  # https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html#BATTLEOPENED:server
  defp do_reply(:battle_opened, battle) when is_map(battle) do
    type =
      case battle.type do
        :normal -> 0
        :replay -> 1
      end

    nattype =
      case battle.nattype do
        :none -> 0
        :holepunch -> 1
        :fixed -> 2
      end

    passworded = if battle.password == nil, do: 0, else: 1

    "BATTLEOPENED #{battle.id} #{type} #{nattype} #{battle.founder_name} #{battle.ip} #{
      battle.port
    } #{battle.max_players} #{passworded} #{battle.rank} #{battle.map_hash} #{battle.engine_name}\t#{
      battle.engine_version
    }\t#{battle.map_name}\t#{battle.name}\t#{battle.game_name}\n"
  end

  defp do_reply(:battle_opened, battle_id) do
    do_reply(:battle_opened, Battle.get_battle(battle_id))
  end

  defp do_reply(:open_battle_success, battle_id) do
    "OPENBATTLE #{battle_id}\n"
  end

  defp do_reply(:open_battle_failure, reason) do
    "OPENBATTLEFAILED #{reason}\n"
  end

  defp do_reply(:battle_closed, battle_id) do
    "BATTLECLOSED #{battle_id}\n"
  end

  defp do_reply(:request_battle_status, nil) do
    "REQUESTBATTLESTATUS\n"
  end

  defp do_reply(:update_battle, battle) when is_map(battle) do
    locked = if battle.locked, do: "1", else: "0"

    "UPDATEBATTLEINFO #{battle.id} #{battle.spectator_count} #{locked} #{battle.map_hash} #{
      battle.map_name
    }\n"
  end

  defp do_reply(:update_battle, battle_id) do
    do_reply(:update_battle, Battle.get_battle(battle_id))
  end

  defp do_reply(:join_battle_success, battle) do
    "JOINBATTLE #{battle.id} #{battle.game_hash}\n"
  end

  defp do_reply(:join_battle_failure, battle) do
    "JOINBATTLE #{battle.id} #{battle.game_hash}\n"
  end

  defp do_reply(:add_start_rectangle, {team, [left, top, right, bottom]}) do
    "ADDSTARTRECT #{team} #{left} #{top} #{right} #{bottom}\n"
  end

  defp do_reply(:remove_start_rectangle, team) do
    "REMOVESTARTRECT #{team}\n"
  end

  defp do_reply(:add_script_tags, tags) do
    tags =
      tags
      |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
      |> Enum.join("\t")

    "SETSCRIPTTAGS " <> tags <> "\n"
  end

  defp do_reply(:remove_script_tags, keys) do
    "REMOVESCRIPTTAGS " <> Enum.join(keys, "\t") <> "\n"
  end

  defp do_reply(:enable_all_units, _units) do
    "ENABLEALLUNITS\n"
  end

  defp do_reply(:enable_units, units) do
    "ENABLEUNITS " <> Enum.join(units, " ") <> "\n"
  end

  defp do_reply(:disable_units, units) do
    "DISABLEUNITS " <> Enum.join(units, " ") <> "\n"
  end

  defp do_reply(:add_bot_to_battle, {battle_id, bot}) do
    status = SpringLib.create_battle_status(bot)

    "ADDBOT #{battle_id} #{bot.name} #{bot.owner_name} #{status} #{bot.team_colour} #{bot.ai_dll}\n"
  end

  defp do_reply(:remove_bot_from_battle, {battle_id, botname}) do
    "REMOVEBOT #{battle_id} #{botname}\n"
  end

  defp do_reply(:update_bot, {battle_id, bot}) do
    status = SpringLib.create_battle_status(bot)
    "UPDATEBOT #{battle_id} #{bot.name} #{status} #{bot.team_colour}\n"
  end

  defp do_reply(:battle_players, battle) do
    battle.players
    |> Parallel.map(fn player_id ->
      pname = User.get_username(player_id)
      "JOINEDBATTLE #{battle.id} #{pname}\n"
    end)
  end

  # Client
  defp do_reply(:registration_accepted, nil) do
    "REGISTRATIONACCEPTED\n"
  end

  defp do_reply(:registration_denied, reason) do
    "REGISTRATIONDENIED #{reason}\n"
  end

  defp do_reply(:client_status, client) do
    status = SpringLib.create_client_status(client)
    "CLIENTSTATUS #{client.name} #{status}\n"
  end

  defp do_reply(:client_battlestatus, {userid, battlestatus, team_colour}) do
    name = User.get_username(userid)
    "CLIENTBATTLESTATUS #{name} #{battlestatus} #{team_colour}\n"
  end

  defp do_reply(:client_battlestatus, nil), do: nil
  defp do_reply(:client_battlestatus, client) do
    status = SpringLib.create_battle_status(client)
    "CLIENTBATTLESTATUS #{client.name} #{status} #{client.team_colour}\n"
  end

  defp do_reply(:user_logged_in, userid) do
    user = User.get_user_by_id(userid)

    [
      do_reply(:add_user, user),
      do_reply(:client_status, Client.get_client_by_id(userid))
    ]
  end

  defp do_reply(:user_logged_out, {userid, username}) do
    do_reply(:remove_user, {userid, username})
  end

  # Commands
  defp do_reply(:ring, {ringer_id, state_user}) do
    if ringer_id not in (state_user.ignored || []) do
      ringer_name = User.get_username(ringer_id)
      "RING #{ringer_name}\n"
    end
  end

  # Request password reset
  defp do_reply(:reset_password_actual_accepted, nil) do
    "RESETPASSWORDACCEPTED\n"
  end

  defp do_reply(:reset_password_actual_denied, reason) do
    "RESETPASSWORDDENIED #{reason}\n"
  end

  defp do_reply(:reset_password_request_accepted, nil) do
    "RESETPASSWORDREQUESTACCEPTED\n"
  end

  defp do_reply(:reset_password_request_denied, reason) do
    "RESETPASSWORDREQUESTDENIED #{reason}\n"
  end

  # Email change request
  defp do_reply(:change_email_accepted, nil) do
    "CHANGEEMAILACCEPTED\n"
  end

  defp do_reply(:change_email_denied, reason) do
    "CHANGEEMAILDENIED #{reason}\n"
  end

  defp do_reply(:change_email_request_accepted, nil) do
    "CHANGEEMAILREQUESTACCEPTED\n"
  end

  defp do_reply(:change_email_request_denied, reason) do
    "CHANGEEMAILREQUESTDENIED #{reason}\n"
  end


  # Chat
  defp do_reply(:join_success, room_name) do
    "JOIN #{room_name}\n"
  end

  defp do_reply(:join_failure, {room_name, reason}) do
    "JOINFAILED #{room_name} #{reason}\n"
  end

  defp do_reply(:joined_room, {username, room_name}) do
    "JOINED #{room_name} #{username}\n"
  end

  defp do_reply(:left_room, {username, room_name}) do
    "LEFT #{room_name} #{username}\n"
  end

  defp do_reply(:channel_topic, {room_name, author_name}) do
    "CHANNELTOPIC #{room_name} #{author_name}\n"
  end

  defp do_reply(:channel_members, {members, room_name}) do
    "CLIENTS #{room_name} #{members}\n"
  end

  defp do_reply(:list_channels, nil) do
    channels =
      Room.list_rooms()
      |> Enum.map(fn room ->
        "CHANNEL #{room.name} #{Enum.count(room.members)}\n"
      end)

    (["CHANNELS\n"] ++ channels ++ ["ENDOFCHANNELS\n"])
    |> Enum.join("")
  end

  defp do_reply(:sent_direct_message, {to_id, msg}) do
    to_name = User.get_username(to_id)
    "SAYPRIVATE #{to_name} #{msg}\n"
  end

  defp do_reply(:direct_message, {from_id, msg, state_user}) do
    if from_id not in (state_user.ignored || []) do
      from_name = User.get_username(from_id)
      "SAIDPRIVATE #{from_name} #{msg}\n"
    end
  end

  defp do_reply(:chat_message, {from_id, room_name, msg, state_user}) do
    if from_id not in (state_user.ignored || []) do
      from_name = User.get_username(from_id)
      "SAID #{room_name} #{from_name} #{msg}\n"
    end
  end

  defp do_reply(:chat_message_ex, {from_id, room_name, msg, state_user}) do
    if from_id not in (state_user.ignored || []) do
      from_name = User.get_username(from_id)
      "SAIDEX #{room_name} #{from_name} #{msg}\n"
    end
  end

  defp do_reply(:add_user_to_room, {userid, room_name}) do
    username = User.get_username(userid)
    "JOINED #{room_name} #{username}\n"
  end

  # Battle
  defp do_reply(:remove_user_from_room, {userid, room_name}) do
    username = User.get_username(userid)
    "LEFT #{room_name} #{username}\n"
  end

  defp do_reply(:add_user_to_battle, {userid, battle_id}) do
    username = User.get_username(userid)
    "JOINEDBATTLE #{battle_id} #{username}\n"
  end

  defp do_reply(:remove_user_from_battle, {userid, battle_id}) do
    username = User.get_username(userid)
    "LEFTBATTLE #{battle_id} #{username}\n"
  end

  defp do_reply(:kick_user_from_battle, {userid, battle_id}) do
    username = User.get_username(userid)
    "KICKFROMBATTLE #{battle_id} #{username}\n"
  end

  defp do_reply(:forcequit_battle, nil) do
    "FORCEQUITBATTLE\n"
  end

  defp do_reply(:battle_message, {userid, msg, _battle_id}) do
    username = User.get_username(userid)
    "SAIDBATTLE #{username} #{msg}\n"
  end

  defp do_reply(:battle_message_ex, {userid, msg, _battle_id}) do
    username = User.get_username(userid)
    "SAIDBATTLEEX #{username} #{msg}\n"
  end

  defp do_reply(:servermsg, msg) do
    "SERVERMSG #{msg}\n"
  end

  defp do_reply(atom, data) do
    Logger.error(
      "No reply match in spring_out.ex for atom: #{atom} and data: #{Kernel.inspect(data)}"
    )

    ""
  end

  # This sends a message to the self to send out a message
  @spec _send(String.t() | list(), String.t(), map) :: any()
  defp _send(msg, msg_id, state) do
    _send(msg, state.socket, state.transport, msg_id)
  end

  defp _send("", _, _, _), do: nil
  defp _send([], _, _, _), do: nil

  defp _send(msg, socket, transport, msg_id) when is_list(msg) do
    _send(Enum.join(msg, ""), socket, transport, msg_id)
  end

  defp _send(msg, socket, transport, msg_id) do
    # If no line return at the end we should warn about that
    # I've made the mistake of forgetting it and wondering
    # why stuff wasn't working so it's staying here
    if not String.ends_with?(msg, "\n") do
      Logger.warn("Attempting to send message without newline at the end - #{msg}")
    end

    msg =
      if msg_id != "" and msg_id != nil do
        msg
        |> String.trim()
        |> String.split("\n")
        |> Enum.map(fn m -> "#{msg_id} #{m}\n" end)
        |> Enum.join("")
      else
        msg
      end

    Logger.debug("--> #{Kernel.inspect(socket)} #{TcpServer.format_log(msg)}")
    transport.send(socket, msg)
    # msg
    # |> String.split("\n")
    # |> Enum.filter(fn part -> part != "" end)
    # |> Enum.each(fn part ->
    #   transport.send(socket, part <> "\n")
    # end)
  end
end