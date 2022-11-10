30.times do |i|
  Article.create!(
    title: "テスト記事#{i + 1}",
    body: "本文#{i + 1}"
  )
end
