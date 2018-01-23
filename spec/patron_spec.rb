require 'rails_helper'

RSpec.describe ::Patreon::Patron do

  Fabricator(:oauth2_user_info) do
    provider "patreon"
    user
  end

  Fabricator(:user_custom_field) do
    name "patreon_id"
    user
  end

  let(:patrons) { { "111111" => { "email" => "foo@bar.com" }, "111112" => { "email" => "boo@far.com" },  "111113" => { "email" => "roo@aar.com" } } }
  let(:pledges) { { "111111" => "100", "111112" => "500" } }
  let(:rewards) { { "0" => { title: "All Patrons", amount_cents: "0" }, "4589" => { title: "Sponsers", amount_cents: "1000" } } }
  let(:reward_users) { { "0" => ["111111", "111112"], "4589" => ["111112"] } }
  let(:titles) { { "111111" => "All Patrons", "111112" => "All Patrons, Sponsers" } }

  before do
    ::Patreon.set("users", patrons)
    ::Patreon.set("pledges", pledges)
    ::Patreon.set("rewards", rewards)
    ::Patreon.set("reward-users", reward_users)
  end

  it "should find rewarded user ids by rewards" do
    ids = described_class.get_ids_by_rewards(rewards.keys)
    expect(ids).to eq(["111111", "111112"])
  end

  it "should find local users matching Patreon user info" do
    Fabricate(:oauth2_user_info, uid: "111112")
    Fabricate(:user, email: "foo@bar.com")

    local_users = described_class.get_local_users
    expect(local_users.count).to eq(2)

    local_users.each do |user|
      cf = user.custom_fields
      id = cf["patreon_id"]
      expect(described_class.get("patreon_email", user)).to eq(patrons[id]["email"])
      expect(described_class.get("patreon_amount_cents", user)).to eq(pledges[id])
      expect(described_class.get("patreon_rewards", user)).to eq(titles[id])
    end
  end

  it "should sync Discourse groups with Patreon users" do
    ouser = Fabricate(:oauth2_user_info, uid: "111112")
    user = Fabricate(:user, email: "foo@bar.com")

    group1 = Fabricate(:group)
    group2 = Fabricate(:group)
    filters = { group1.id.to_s => ["0"], group2.id.to_s => ["4589"] }
    Patreon.set("filters", filters)
    described_class.sync_groups
    expect(group1.users.to_a).to eq([ouser.user, user])
    expect(group2.users.to_a).to eq([ouser.user])
  end

  it "should get already linked user via custom field" do
    cf = Fabricate(:user_custom_field, value: "111111")
    expect(described_class.get_local_users[0]).to eq(cf.user)
  end

end
