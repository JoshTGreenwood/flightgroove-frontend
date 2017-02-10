module Explorer.Subscriptions exposing (subscriptions)

import Explorer.Model exposing (Model)
import Explorer.Messages as Messages
import Explorer.MapComp.MapMessages as MapMessages
import Explorer.Ports as Ports


subscriptions : Model -> Sub Messages.Msg
subscriptions model =
    Sub.batch
        [ Ports.mapCallback <| Messages.MapTag << MapMessages.MapResponse
        , Ports.popupCallback <| Messages.MapTag << MapMessages.PopupResponse
        , Ports.popupSelected <| Messages.MapTag << MapMessages.SelectDestination
        ]
