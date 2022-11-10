10.times do |i|
  Article.create!(
    title: "テスト記事#{i}",
    body: "本文#{i}"
  )
end
