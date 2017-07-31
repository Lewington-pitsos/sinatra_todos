def new_id current_ids
  id = (("A".."Z").to_a.sample(3) + (0..9).to_a.sample(3)).join
  return new_id if current_ids.include?(id)
  id
end

p new_id []
