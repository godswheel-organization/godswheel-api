defmodule GodsWheelWeb.Sermon.SermonJSON do
  def index(%{entries: entries, meta: meta}) do
    GodsWheelWeb.Response.success(
      Enum.map(entries, &sermon_summary/1),
      meta
    )
  end

  def show(sermon), do: GodsWheelWeb.Response.success(sermon(sermon))

  def categories(%{entries: entries, meta: meta}) do
    GodsWheelWeb.Response.success(
      Enum.map(entries, &category/1),
      meta
    )
  end

  def speakers(%{entries: entries, meta: meta}) do
    GodsWheelWeb.Response.success(
      Enum.map(entries, &speaker/1),
      meta
    )
  end

  defp sermon_summary(sermon) do
    %{
      id: sermon.id,
      title: sermon.title,
      slug: sermon.slug,
      thumbnail_url: sermon.thumbnail_url,
      duration_seconds: sermon.duration_seconds,
      published_at: sermon.published_at,
      speaker: speaker_summary(sermon.speaker),
      categories: Enum.map(sermon.categories, &category_summary/1)
    }
  end

  defp sermon(sermon) do
    %{
      id: sermon.id,
      title: sermon.title,
      slug: sermon.slug,
      description: sermon.description,
      audio_url: sermon.audio_url,
      thumbnail_url: sermon.thumbnail_url,
      scripture_reference: sermon.scripture_reference,
      duration_seconds: sermon.duration_seconds,
      language: sermon.language,
      published_at: sermon.published_at,
      speaker: speaker(sermon.speaker),
      categories: Enum.map(sermon.categories, &category/1)
    }
  end

  defp category_summary(category) do
    %{
      id: category.id,
      name: category.name,
      slug: category.slug
    }
  end

  defp category(category) do
    %{
      id: category.id,
      name: category.name,
      slug: category.slug,
      description: category.description
    }
  end

  defp speaker_summary(speaker) do
    %{
      id: speaker.id,
      name: speaker.name
    }
  end

  defp speaker(speaker) do
    %{
      id: speaker.id,
      name: speaker.name,
      bio: speaker.bio,
      image_url: speaker.image_url
    }
  end
end
