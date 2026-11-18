defmodule ThreatShield.Accounts.Role do
  @moduledoc """
  The role of a member in an organisation. `ThreatShield.Accounts.Rights` maps the
  rights to the roles.
  """
  use Ash.Type.Enum,
    values: [
      owner: "Manages the organisation, its members and invites, and edits all content.",
      editor: "Edits the organisation and creates, edits and deletes its content.",
      viewer: "Reads the organisation and its content."
    ]
end
