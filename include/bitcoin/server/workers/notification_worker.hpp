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
#ifndef LIBBITCOIN_SERVER_NOTIFICATION_WORKER_HPP
#define LIBBITCOIN_SERVER_NOTIFICATION_WORKER_HPP

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <unordered_set>
#include <bitcoin/system.hpp>
#include <bitcoin/server/define.hpp>
#include <bitcoin/server/messages/message.hpp>
#include <bitcoin/server/messages/route.hpp>
#include <bitcoin/server/messages/subscription.hpp>
#include <bitcoin/server/settings.hpp>

// Include after define.hpp (placeholders).
#include <boost/bimap.hpp>
#include <boost/bimap/multiset_of.hpp>

namespace libbitcoin {
namespace server {

class server_node;

// This class is thread safe.
// Provide address and stealth notifications to the query service.
class BCS_API notification_worker
  : public bc::protocol::zmq::worker
{
public:
    typedef std::shared_ptr<notification_worker> ptr;

    /// Construct a notification worker.
    notification_worker(bc::protocol::zmq::authenticator& authenticator,
        server_node& node, bool secure);

    /// Start the worker.
    bool start() override;

    /// Subscribe to payment key notifications.
    virtual system::code subscribe_key(const message& request,
        system::hash_digest&& key, bool unsubscribe);

    /// Subscribe to stealth notifications.
    virtual system::code subscribe_stealth(const message& request,
        system::binary&& prefix_filter, bool unsubscribe);

protected:

    // Implement the service.
    virtual void work() override;

private:
    typedef bc::protocol::zmq::socket socket;
    typedef std::unordered_set<uint32_t> stealth_set;
    typedef std::unordered_set<system::hash_digest> key_set;

    // Purge:     route.created (constant: 1).
    // Notify:    address (constant: 1).
    // Subscribe: address + route (constant + linear).
    // Drop:      route (linear) [not implemented].
    // A bidirectional map is used for efficient hash and age retrieval.
    // This produces the effect of a circular hash table of subscriptions.
    // Since address hashes are fixed length, 1 query returns all matches.
    typedef boost::bimaps::bimap<
        boost::bimaps::multiset_of<system::hash_digest>,
        boost::bimaps::multiset_of<subscription>> key_subscriptions;

    // Purge:     route.created (constant: 1).
    // Notify:    prefix (constant: 24 [32-8]).
    // Subscribe: prefix + route (constant + linear).
    // Drop:      route (linear) [not implemented].
    // A bidirectional map is used for efficient prefix and age retrieval.
    // This produces the effect of a circular hash table of subscriptions.
    // Since prefix matching varies by length, but is constrained to 8-32 bits,
    // we simply query 24 times against the hash table to find all matches.
    typedef boost::bimaps::bimap<
        boost::bimaps::multiset_of<system::binary>,
        boost::bimaps::multiset_of<subscription >> stealth_subscriptions;

    static time_t current_time();
    time_t cutoff_time() const;
    int32_t purge_milliseconds() const;
    void purge();

    bool key_subscriptions_empty() const;
    bool stealth_subscriptions_empty() const;

    bool handle_reorganization(const system::code& ec, size_t fork_height,
        system::block_const_ptr_list_const_ptr incoming,
        system::block_const_ptr_list_const_ptr outgoing);
    bool handle_transaction_pool(const system::code& ec,
        system::transaction_const_ptr tx);

    void notify_block(socket& dealer, size_t height,
        system::block_const_ptr block);
    void notify_transaction(socket& dealer, size_t height,
        const system::chain::transaction& tx);
    void notify(socket& dealer, const key_set& keys,
        const stealth_set& prefixes, size_t height,
        const system::hash_digest& tx_hash);

    socket::ptr connect();
    bool send(socket& dealer, const subscription& routing,
        const std::string& command, const system::code& status, size_t height,
        const system::hash_digest& tx_hash);

    // These are thread safe.
    const bool secure_;
    const std::string security_;
    const bc::server::settings& settings_;
    const bc::protocol::settings& external_;
    const bc::protocol::settings internal_;
    const system::config::endpoint& worker_;
    bc::protocol::zmq::authenticator& authenticator_;
    server_node& node_;

    // These are protected by mutex.
    key_subscriptions key_subscriptions_;
    stealth_subscriptions stealth_subscriptions_;
    mutable system::upgrade_mutex key_mutex_;
    mutable system::upgrade_mutex stealth_mutex_;
};

} // namespace server
} // namespace libbitcoin

#endif
