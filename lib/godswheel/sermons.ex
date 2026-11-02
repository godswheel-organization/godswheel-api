defmodule GodsWheel.Sermons do
  import Ecto.Query, warn: false

  alias GodsWheel.Repo
  alias GodsWheel.Sermons.{Category, Scripture, Sermon, Speaker}

  @default_limit 20
  @max_limit 100
  @sermon_summary_fields [
    :id,
    :title,
    :slug,
    :thumbnail_url,
    :duration_seconds,
    :published_at,
    :speaker_id
  ]
  def list_sermons(params \\ %{}) do
    now = DateTime.utc_now()

    with {:ok, pagination} <- pagination(params),
         {:ok, filters} <- sermon_filters(params) do
      speaker_query =
        from speaker in Speaker,
          select: struct(speaker, [:id, :name])

      category_query =
        from category in Category,
          select: struct(category, [:id, :name, :slug])

      query =
        from sermon in Sermon,
          as: :sermon,
          where: not is_nil(sermon.published_at) and sermon.published_at <= ^now,
          select: struct(sermon, ^@sermon_summary_fields),
          preload: [
            speaker: ^speaker_query,
            categories: ^category_query
          ]

      query = apply_sermon_filters(query, filters)
      query = order_sermons(query, filters.sort)

      total_entries = count_entries(query)

      entries =
        query
        |> limit(^pagination.limit)
        |> offset(^((pagination.page - 1) * pagination.limit))
        |> Repo.all()

      {:ok, %{entries: entries, meta: pagination_meta(pagination, total_entries)}}
    end
  end

  def get_sermon(id) when is_binary(id) do
    now = DateTime.utc_now()

    case Repo.one(
           from sermon in Sermon,
             where:
               sermon.id == ^id and not is_nil(sermon.published_at) and
                 sermon.published_at <= ^now,
             preload: [:speaker, :categories, :scriptures]
         ) do
      nil -> {:error, :not_found}
      sermon -> {:ok, sermon}
    end
  end

  def get_sermon(_id), do: {:error, :not_found}

  def get_sermon_audio(id) when is_binary(id) do
    now = DateTime.utc_now()

    case Repo.one(
           from sermon in Sermon,
             where:
               sermon.id == ^id and not is_nil(sermon.published_at) and
                 sermon.published_at <= ^now,
             select: sermon.audio_url
         ) do
      nil ->
        {:error, :not_found}

      audio_key when is_binary(audio_key) ->
        if String.trim(audio_key) == "" do
          {:error, :audio_not_found}
        else
          {:ok, audio_key}
        end
    end
  end

  def get_sermon_audio(_id), do: {:error, :not_found}

  def list_categories(params \\ %{}) do
    with {:ok, pagination} <- pagination(params) do
      query = from(category in Category)
      query = apply_name_search(query, params)
      total_entries = Repo.aggregate(query, :count, :id)

      entries =
        query
        |> order_by([category], asc: category.name, asc: category.id)
        |> limit(^pagination.limit)
        |> offset(^((pagination.page - 1) * pagination.limit))
        |> Repo.all()

      {:ok, %{entries: entries, meta: pagination_meta(pagination, total_entries)}}
    end
  end

  def list_speakers(params \\ %{}) do
    with {:ok, pagination} <- pagination(params) do
      query = from(speaker in Speaker)
      query = apply_name_search(query, params)
      total_entries = Repo.aggregate(query, :count, :id)

      entries =
        query
        |> order_by([speaker], asc: speaker.name, asc: speaker.id)
        |> limit(^pagination.limit)
        |> offset(^((pagination.page - 1) * pagination.limit))
        |> Repo.all()

      {:ok, %{entries: entries, meta: pagination_meta(pagination, total_entries)}}
    end
  end

  defp sermon_filters(params) do
    with {:ok, category_id} <- optional_uuid(params, "category_id"),
         {:ok, speaker_id} <- optional_uuid(params, "speaker_id"),
         {:ok, sort} <- sort_option(params),
         {:ok, scripture} <- scripture_filter(params["scripture"]) do
      {:ok,
       %{
         search: normalized_search(params["search"]),
         search_in: search_fields(params["search_in"]),
         category_id: category_id,
         speaker_id: speaker_id,
         scripture: scripture,
         language: normalized_search(params["language"]),
         sort: sort
       }}
    end
  end

  defp apply_sermon_filters(query, filters) do
    query
    |> maybe_search_sermons(filters.search, filters.search_in)
    |> maybe_filter_category(filters.category_id)
    |> maybe_filter_speaker(filters.speaker_id)
    |> maybe_filter_scripture(filters.scripture)
    |> maybe_filter_language(filters.language)
  end

  defp maybe_search_sermons(query, nil, _search_in), do: query

  defp maybe_search_sermons(query, search, search_in) do
    pattern = "%#{search}%"

    search_condition =
      Enum.reduce(search_in, dynamic(false), fn
        "title", condition ->
          dynamic(
            [sermon],
            ^condition or ilike(sermon.title, ^pattern)
          )

        "description", condition ->
          dynamic(
            [sermon],
            ^condition or ilike(sermon.description, ^pattern)
          )
      end)

    where(query, ^search_condition)
  end

  defp search_fields(value) when is_list(value) do
    fields =
      value
      |> Enum.filter(&(&1 in ["title", "description"]))
      |> Enum.uniq()

    if fields == [], do: ["title", "description"], else: fields
  end

  defp search_fields(_value), do: ["title", "description"]

  defp maybe_filter_category(query, nil), do: query

  defp maybe_filter_category(query, category_id) do
    query
    |> join(:inner, [sermon], category in assoc(sermon, :categories))
    |> where([_sermon, category], category.id == ^category_id)
  end

  defp maybe_filter_speaker(query, nil), do: query

  defp maybe_filter_speaker(query, speaker_id),
    do: where(query, [sermon], sermon.speaker_id == ^speaker_id)

  defp maybe_filter_scripture(query, nil), do: query

  defp maybe_filter_scripture(query, scripture_filter) do
    scripture_query =
      from scripture in Scripture,
        join: association in "sermon_scriptures",
        on: field(association, :scripture_id) == scripture.id,
        where: field(association, :sermon_id) == parent_as(:sermon).id

    scripture_query =
      scripture_query
      |> where(
        [scripture],
        fragment("lower(?) = lower(?)", scripture.book, ^scripture_filter.book)
      )
      |> maybe_filter_scripture_chapter(scripture_filter.chapter)
      |> maybe_filter_scripture_verses(scripture_filter.start_verse, scripture_filter.end_verse)

    where(query, [sermon: _sermon], exists(subquery(scripture_query)))
  end

  defp maybe_filter_scripture_chapter(query, nil), do: query

  defp maybe_filter_scripture_chapter(query, chapter) do
    where(query, [scripture], scripture.chapter == ^chapter)
  end

  defp maybe_filter_scripture_verses(query, nil, nil), do: query

  defp maybe_filter_scripture_verses(query, start_verse, end_verse) do
    where(
      query,
      [scripture],
      scripture.start_verse <= ^end_verse and scripture.end_verse >= ^start_verse
    )
  end

  defp scripture_filter(nil), do: {:ok, nil}

  defp scripture_filter(value) when is_binary(value) do
    value = String.trim(value)

    case Regex.named_captures(
           ~r/^(?<book>.+?)\s+(?<chapter>\d+)(?::(?<start_verse>\d+)(?:\s*-\s*(?<end_verse>\d+))?)?$/,
           value
         ) do
      %{"book" => book, "chapter" => chapter} = captures ->
        parse_scripture_parts(
          book,
          chapter,
          empty_to_nil(captures["start_verse"]),
          empty_to_nil(captures["end_verse"])
        )

      nil when value != "" ->
        if String.match?(value, ~r/\d/) do
          {:error, {:invalid_filter, "scripture"}}
        else
          {:ok, %{book: value, chapter: nil, start_verse: nil, end_verse: nil}}
        end

      _ ->
        {:ok, nil}
    end
  end

  defp scripture_filter(_value), do: {:error, {:invalid_filter, "scripture"}}

  defp parse_scripture_parts(book, chapter, start_verse, end_verse) do
    with true <- String.trim(book) != "",
         {chapter, ""} <- Integer.parse(chapter),
         true <- chapter > 0,
         {:ok, start_verse} <- optional_positive_integer(start_verse),
         {:ok, end_verse} <- optional_positive_integer(end_verse),
         true <- is_nil(end_verse) or (not is_nil(start_verse) and end_verse >= start_verse) do
      {:ok,
       %{
         book: String.trim(book),
         chapter: chapter,
         start_verse: start_verse,
         end_verse: end_verse || start_verse
       }
       |> then(fn filter ->
         if is_nil(start_verse), do: %{filter | end_verse: nil}, else: filter
       end)}
    else
      _ -> {:error, {:invalid_filter, "scripture"}}
    end
  end

  defp optional_positive_integer(nil), do: {:ok, nil}

  defp optional_positive_integer(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> {:ok, integer}
      _ -> {:error, :invalid_integer}
    end
  end

  defp empty_to_nil(nil), do: nil
  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp maybe_filter_language(query, nil), do: query

  defp maybe_filter_language(query, language) do
    where(query, [sermon], ilike(sermon.language, ^"%#{language}%"))
  end

  defp order_sermons(query, "oldest") do
    order_by(query, [sermon], asc: sermon.published_at, asc: sermon.id)
  end

  defp order_sermons(query, _sort) do
    order_by(query, [sermon], desc: sermon.published_at, desc: sermon.id)
  end

  defp count_entries(query) do
    Repo.aggregate(query, :count, :id)
  end

  defp apply_name_search(query, params) do
    case normalized_search(params["search"]) do
      nil -> query
      search -> where(query, [record], ilike(record.name, ^"%#{search}%"))
    end
  end

  defp pagination(params) do
    with {:ok, page} <- positive_integer(params["page"], 1),
         {:ok, limit} <- positive_integer(params["limit"], @default_limit) do
      {:ok, %{page: page, limit: min(limit, @max_limit)}}
    end
  end

  defp positive_integer(nil, default), do: {:ok, default}
  defp positive_integer(value, _default) when is_integer(value) and value > 0, do: {:ok, value}

  defp positive_integer(value, _default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> {:ok, integer}
      _ -> {:error, :invalid_pagination}
    end
  end

  defp positive_integer(_value, _default), do: {:error, :invalid_pagination}

  defp optional_uuid(params, key) do
    case params[key] do
      nil ->
        {:ok, nil}

      value when is_binary(value) ->
        case Ecto.UUID.cast(value) do
          {:ok, uuid} -> {:ok, uuid}
          :error -> {:error, {:invalid_filter, key}}
        end

      _ ->
        {:error, {:invalid_filter, key}}
    end
  end

  defp sort_option(params) do
    case params["sort"] do
      nil -> {:ok, "newest"}
      sort when sort in ["newest", "oldest"] -> {:ok, sort}
      _ -> {:error, {:invalid_filter, "sort"}}
    end
  end

  defp normalized_search(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      search_term -> search_term
    end
  end

  defp normalized_search(_value), do: nil

  defp pagination_meta(pagination, total_entries) do
    %{
      page: pagination.page,
      limit: pagination.limit,
      total_entries: total_entries,
      total_pages: ceil(total_entries / pagination.limit),
      hasNextPage: pagination.page < ceil(total_entries / pagination.limit),
      hasPrevPage: pagination.page > 1 and total_entries > 0
    }
  end
end
