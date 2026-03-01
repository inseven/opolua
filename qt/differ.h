// Copyright (C) 2021-2026 Jason Morley, Tom Sutcliffe
// See LICENSE file for license information.

#ifndef DIFFER_H
#define DIFFER_H

#include <QVector>

/*
This helper offers a general way of diffing a container (currently, always a QVector) to produce callbacks on every
type of change (item added, removed, updated). This is very useful for converting a container snapshot into a bunch
of model updates for eq a QAbstractItemModel.
*/
template<typename T>
struct Differ
{
    QVector<T>& prev;
    const QVector<T>& next;
    std::function<bool(const T&, const T&)> sameItem;
    std::function<bool(const T&, const T&)> equals;
    std::function<void(int)> willDelete;
    std::function<void(int)> didDelete;
    std::function<void(int, const T&)> willAdd;
    std::function<void(int, const T&)> didAdd;
    std::function<void(int, const T&)> willUpdate;
    std::function<void(int, const T&, const T&)> didUpdate;

    void diff() {
        int idx = 0;
        // idx is always valid in next; prev is massaged as it is iterated such that indexes < idx are the same as those
        // in next.
        while (idx < next.count()) {
            const T& newVal = next[idx];
            if (idx < prev.count()) {
                const T& prevVal = prev[idx];
                if (sameItem(prevVal, newVal)) {
                    if (equals && !equals(newVal, prevVal)) {
                        if (willUpdate) willUpdate(idx, newVal);
                        auto oldVal = std::move(prev[idx]);
                        prev[idx] = newVal;
                        if (didUpdate) didUpdate(idx, oldVal, newVal);
                    }
                    idx++;
                } else {
                    // Has prevVal been removed? Note, this findItemInNext could be more efficient in some cases where
                    // we know there's a point in next beyond which it's not worth looking. Not sure how to express
                    // that generically though, for now this could be a little inefficient.
                    int found = findItemInNext(idx + 1, prevVal);
                    if (found <= idx) {
                        // prevVal not found in next
                        if (willDelete) willDelete(idx);
                        prev.remove(idx);
                        if (didDelete) willDelete(idx);
                    } else {
                        // Found it, items between idx and foundIdx are new
                        for (int i = idx; i < found; i++) {
                            const auto& val = next[i];
                            if (willAdd) willAdd(i, val);
                            prev.insert(i, val);
                            if (didAdd) didAdd(i, val);
                        }
                        idx = found; // So we test for updated
                    }
                }
            } else {
                // New item at end of list
                if (willAdd) willAdd(idx, newVal);
                prev.insert(idx, newVal);
                if (didAdd) didAdd(idx, newVal);
                idx++;
            }
        }

        while (idx < prev.count()) {
            // If we get here everything from idx up has been removed from next
            if (willDelete) willDelete(idx);
            prev.remove(idx);
            if (didDelete) didDelete(idx);
        }
    }

    // Simplified API for situations that don't need both will... and did... callbacks.
    static void diff(QVector<T>& prev, const QVector<T>& next, 
        std::function<bool(const T&, const T&)> sameItem,
        std::function<void(int)> deleted,
        std::function<void(int, const T&)> added,
        std::function<void(int, const T&)> updated)
    {
        Differ<T> d = {
            .prev = prev,
            .next = next,
            .sameItem = sameItem,
            .equals = [](const auto& a, const auto& b) { return a == b; },
            .willDelete = deleted,
            .didDelete = nullptr,
            .willAdd = added,
            .didAdd = nullptr,
            .willUpdate = updated,
            .didUpdate = nullptr,
        };
        d.diff();        
    }

private:
    int findItemInNext(int startIdx, const T& item) {
        const int n = next.count();
        for (int i = startIdx; i < n; i++) {
            if (sameItem(item, next[i])) {
                return i;
            }
        }
        return -1;
    }
};

#endif // DIFFER_H
