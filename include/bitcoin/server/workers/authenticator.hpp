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
#ifndef LIBBITCOIN_SERVER_SECURE_AUTHENTICATOR_HPP
#define LIBBITCOIN_SERVER_SECURE_AUTHENTICATOR_HPP

#include <memory>
#include <bitcoin/protocol.hpp>
#include <bitcoin/server/define.hpp>
#include <bitcoin/server/settings.hpp>

namespace libbitcoin {
namespace server {

class server_node;

class BCS_API authenticator
  : public bc::protocol::zmq::authenticator
{
public:
    typedef std::shared_ptr<authenticator> ptr;

    /// Construct an instance of the authenticator.
    authenticator(server_node& node);

    /// Apply authentication to the socket.
    bool apply(bc::protocol::zmq::socket& socket, const std::string& domain,
        bool secure);
};

} // namespace server
} // namespace libbitcoin

#endif
