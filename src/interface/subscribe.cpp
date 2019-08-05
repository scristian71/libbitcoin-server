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
#include <bitcoin/server/interface/subscribe.hpp>

#include <cstddef>
#include <cstdint>
#include <functional>
#include <utility>
#include <bitcoin/system.hpp>
#include <bitcoin/server/messages/message.hpp>
#include <bitcoin/server/server_node.hpp>

namespace libbitcoin {
namespace server {

using namespace bc::system;
using namespace bc::system::wallet;

void subscribe::key(server_node& node, const message& request,
    send_handler handler)
{
    static constexpr size_t args_size = hash_size;

    const auto& data = request.data();

    if (data.size() != args_size)
    {
        handler(message(request, error::bad_stream));
        return;
    }

    // [ key:32 ]
    auto deserial = make_safe_deserializer(data.begin(), data.end());
    auto key = deserial.read_hash();

    auto ec = node.subscribe_key(request, std::move(key), false);
    handler(message(request, ec));
}

void subscribe::stealth(server_node& node, const message& request,
    send_handler handler)
{
    const auto& data = request.data();

    if (data.empty())
    {
        handler(message(request, error::bad_stream));
        return;
    }

    // [ prefix_bitsize:1 ]
    // [ prefix_blocks:1..4 ]
    auto deserial = make_safe_deserializer(data.begin(), data.end());
    const auto bits = deserial.read_byte();

    if (bits < stealth_address::min_filter_bits ||
        bits > stealth_address::max_filter_bits)
    {
        handler(message(request, error::bad_stream));
        return;
    }

    const auto bytes = binary::blocks_size(bits);

    if (data.size() != sizeof(uint8_t) + bytes)
    {
        handler(message(request, error::bad_stream));
        return;
    }

    const auto blocks = deserial.read_bytes(bytes);

    auto ec = node.subscribe_stealth(request, binary{ bits, blocks }, false);
    handler(message(request, ec));
}

} // namespace server
} // namespace libbitcoin
