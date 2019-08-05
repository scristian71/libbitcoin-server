/**
 * Copyright (c) 2011-2019 libbitcoin developers (see AUTHORS)
 *
 * This file is part of libbitcoin.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include <bitcoin/server/web/heartbeat_socket.hpp>

#include <algorithm>
#include <cstdint>
#include <bitcoin/protocol.hpp>
#include <bitcoin/server/server_node.hpp>
#include <bitcoin/server/settings.hpp>

namespace libbitcoin {
namespace server {

static constexpr auto poll_interval_milliseconds = 100u;

using namespace bc::protocol;
using namespace bc::system::config;
using role = zmq::socket::role;

heartbeat_socket::heartbeat_socket(zmq::context& context, server_node& node,
    bool secure)
  : http::socket(context, node.protocol_settings(), secure),
    settings_(node.server_settings()),
    protocol_settings_(node.protocol_settings())
{
}

void heartbeat_socket::work()
{
    zmq::socket sub(context_, role::subscriber, protocol_settings_);

    const auto endpoint = zeromq_endpoint().to_local();
    const auto ec = sub.connect(endpoint);

    if (ec)
    {
        LOG_ERROR(LOG_SERVER)
            << "Failed to connect to heartbeat service " << endpoint << ": "
            << ec.message();
        return;
    }

    if (!started(start_websocket_handler()))
    {
        LOG_ERROR(LOG_SERVER)
            << "Failed to start " << security_
            << " heartbeat websocket handler.";
        return;
    }

    LOG_INFO(LOG_SERVER)
        << "Bound " << security_ << " websocket heartbeat service to "
        << websocket_endpoint();

    // Default page data can now be set since the base socket's manager has
    // been initialized.
    set_default_page_data(http::get_default_page_data(
        settings_.websockets_query_endpoint(secure_),
        settings_.websockets_heartbeat_endpoint(secure_),
        settings_.websockets_block_endpoint(secure_),
        settings_.websockets_transaction_endpoint(secure_)));

    // TODO: this should be hidden in socket base.
    // Hold a shared reference to the websocket thread_ so that we can
    // properly call stop_websocket_handler on cleanup.
    const auto thread_ref = thread_;

    zmq::poller poller;
    poller.add(sub);

    while (!poller.terminated() && !stopped())
    {
        if (poller.wait(poll_interval_milliseconds).contains(sub.id()) &&
            !handle_heartbeat(sub))
            break;
    }

    const auto sub_stop = sub.stop();
    const auto websocket_stop = stop_websocket_handler();

    if (!sub_stop)
        LOG_ERROR(LOG_SERVER)
            << "Failed to disconnect " << security_
            << " hearbeat websocket service.";

    if (!websocket_stop)
        LOG_ERROR(LOG_SERVER)
            << "Failed to stop " << security_
            << " heartbeat websocket handler.";

    finished(sub_stop && websocket_stop);
}

// Called by this thread's work() method.
// Returns true to continue future notifications.
bool heartbeat_socket::handle_heartbeat(zmq::socket& subscriber)
{
    if (stopped())
        return false;

    zmq::message response;
    subscriber.receive(response);

    static constexpr size_t heartbeat_message_size = 2;
    if (response.empty() || response.size() != heartbeat_message_size)
    {
        LOG_WARNING(LOG_SERVER)
            << "Failure handling heartbeat notification: invalid data.";

        // Don't let a failure here prevent future notifications.
        return true;
    }

    uint16_t sequence{};
    uint64_t height;
    response.dequeue<uint16_t>(sequence);
    response.dequeue<uint64_t>(height);

    broadcast(http::to_json(height, sequence));

    LOG_VERBOSE(LOG_SERVER)
        << "Broadcasted " << security_ << " socket heartbeat [" << height
        << ", " << sequence << "]";
    return true;
}

const endpoint& heartbeat_socket::zeromq_endpoint() const
{
    // The Websocket to zeromq backend internally always uses the
    // local public zeromq endpoint since it does not affect the
    // external security of the websocket endpoint and impacts
    // configuration and performance for no additional gain.
    return settings_.zeromq_heartbeat_endpoint(false /* secure_ */);
}

const endpoint& heartbeat_socket::websocket_endpoint() const
{
    return settings_.websockets_heartbeat_endpoint(secure_);
}

} // namespace server
} // namespace libbitcoin
