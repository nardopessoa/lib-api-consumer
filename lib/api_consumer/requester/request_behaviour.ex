defmodule ApiConsumer.Requester.RequestBehaviour do
  @callback request!(
              method :: atom,
              url :: binary,
              body :: any,
              headers :: any,
              options :: Keyword.t()
            ) :: any
end
