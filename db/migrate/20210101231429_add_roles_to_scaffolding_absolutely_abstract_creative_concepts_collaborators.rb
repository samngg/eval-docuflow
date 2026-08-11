class AddRolesToScaffoldingAbsolutelyAbstractCreativeConceptsCollaborators < ActiveRecord::Migration[6.1]
  def change
    if table_exists?(:scaffolding_absolutely_abstract_creative_concepts_collaborators)
      add_column :scaffolding_absolutely_abstract_creative_concepts_collaborators, :roles, :jsonb, default: []
    end
  end
end
