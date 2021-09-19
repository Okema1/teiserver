defmodule Teiserver.Battle.LobbyChat do
  alias Teiserver.Account.UserCache
  alias Teiserver.{User, Client}
  alias Teiserver.Battle.{Lobby}
  alias Phoenix.PubSub

  @spec say(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def say(userid, "!start" <> s, lobby_id), do: say(userid, "!cv start" <> s, lobby_id)
  def say(userid, "!joinas spec", lobby_id), do: say(userid, "!!joinas spec", lobby_id)
  def say(userid, "!joinas" <> s, lobby_id), do: say(userid, "!cv joinas" <> s, lobby_id)

  def say(userid, "!coordinator start", lobby_id) do
    client = Client.get_client_by_id(userid)
    if client.moderator do
      Lobby.start_coordinator_mode(lobby_id)
    end
    :ok
  end

  def say(userid, msg, lobby_id) do
    msg = String.replace(msg, "!!joinas spec", "!joinas spec")

    case Teiserver.Coordinator.handle_in(userid, msg, lobby_id) do
      :say -> do_say(userid, msg, lobby_id)
      :handled -> :ok
    end
  end

  @spec do_say(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def do_say(userid, msg, lobby_id) do
    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{lobby_id}",
      {:battle_updated, lobby_id, {userid, msg, lobby_id}, :say}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_chat:#{lobby_id}",
      {:lobby_chat, :say, lobby_id, userid, msg}
    )
  end

  @spec sayex(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def sayex(userid, msg, lobby_id) do
    PubSub.broadcast(
      Central.PubSub,
      "legacy_battle_updates:#{lobby_id}",
      {:battle_updated, lobby_id, {userid, msg, lobby_id}, :sayex}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_chat:#{lobby_id}",
      {:lobby_chat, :sayex, lobby_id, userid, msg}
    )
  end

  @spec sayprivateex(Types.userid(), Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def sayprivateex(from_id, to_id, msg, lobby_id) do
    sender = UserCache.get_user_by_id(from_id)
    if not User.is_muted?(sender) do
      PubSub.broadcast(
        Central.PubSub,
        "legacy_user_updates:#{to_id}",
        {:battle_updated, lobby_id, {from_id, msg, lobby_id}, :sayex}
      )
    end
  end
end